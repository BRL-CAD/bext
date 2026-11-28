/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include "../SupplyChain/Process.hpp"

#include <cerrno>
#include <csignal>
#include <iostream>
#include <stdexcept>
#include <system_error>
#include <sys/wait.h>
#include <unistd.h>

namespace {

enum class Scenario { Normal, ParentGrouped, ChildGrouped, ParentDenied, QueryFailed, ChildDenied };

Scenario scenario = Scenario::Normal;
pid_t child_process = 0;
bool parent_group_verified = false;
constexpr int launch_failure = 127;

void require(bool condition, const std::string &message)
{
  if (!condition) throw std::runtime_error(message);
}

}

extern "C" int bext_test_setpgid(pid_t process, pid_t group)
{
  if (process) child_process = process;
  if (scenario == Scenario::ParentGrouped) {
    // Keep the child alive and prevent exec until the parent verifies its group.
    if (!process) {
      if (raise(SIGSTOP)) _exit(launch_failure);
    } else {
      int status = 0;
      pid_t waited;
      do { waited = waitpid(process, &status, WUNTRACED); } while (waited < 0 && errno == EINTR);
      if (waited != process || !WIFSTOPPED(status)) {
        errno = EIO;
        return -1;
      }
    }
  }
  if ((process && (scenario == Scenario::ParentDenied || scenario == Scenario::QueryFailed)) ||
      (!process && scenario == Scenario::ChildDenied)) {
    errno = EPERM;
    return -1;
  }
  const int result = setpgid(process, group);
  if ((process && scenario == Scenario::ParentGrouped) ||
      (!process && scenario == Scenario::ChildGrouped)) {
    if (result) return result;
    errno = EPERM;
    return -1;
  }
  return result;
}

extern "C" pid_t bext_test_getpgid(pid_t process)
{
  if ((process && scenario == Scenario::ParentDenied) ||
      (!process && scenario == Scenario::ChildDenied)) {
    errno = EIO;
    return getppid();
  }
  if (process && scenario == Scenario::QueryFailed) {
    errno = EIO;
    return -1;
  }
  const pid_t group = getpgid(process);
  if (process && scenario == Scenario::ParentGrouped) {
    const int error = errno;
    parent_group_verified = group == process;
    if (kill(process, SIGCONT)) return -1;
    errno = error;
  }
  return group;
}

int main(int argc, char **argv)
{
  try {
    require(argc == 2, "expected a process-group test case");
    const std::string name = argv[1];
    const std::string standard_output = "standard output\n";
    const std::string standard_error = "standard error\n";
    if (name == "--probe") {
      require(getpgrp() == getpid(), "child is outside its own process group");
      std::cout << standard_output;
      std::cerr << standard_error;
      return 0;
    }
    if (name == "parent-grouped") scenario = Scenario::ParentGrouped;
    else if (name == "child-grouped") scenario = Scenario::ChildGrouped;
    else if (name == "parent-denied") scenario = Scenario::ParentDenied;
    else if (name == "query-failed") scenario = Scenario::QueryFailed;
    else if (name == "child-denied") scenario = Scenario::ChildDenied;
    else require(name == "normal", "unknown process-group test case " + name);

    const std::vector<std::string> command = {argv[0], "--probe"};
    if (scenario == Scenario::ParentDenied || scenario == Scenario::QueryFailed) {
      bool rejected = false;
      try {
        bext::run_process(command);
      } catch (const std::system_error &error) {
        rejected = true;
        require(error.code() == std::error_code(EPERM, std::generic_category()),
          "process-group failure lost its original errno");
        const std::string message = error.what();
        require(message.find(command.front()) != std::string::npos, "missing executable in diagnostic");
        require(message.find("errno " + std::to_string(EPERM)) != std::string::npos,
          "missing errno number in diagnostic");
        require(message.find(error.code().message()) != std::string::npos,
          "missing OS error description in diagnostic");
      }
      require(rejected, "unverified process group was accepted");
      require(child_process > 0 && waitpid(child_process, nullptr, WNOHANG) < 0 && errno == ECHILD,
        "rejected child was not reaped");
      return 0;
    }

    constexpr int launch_attempts = 32;
    constexpr auto timeout = std::chrono::seconds(5);
    for (int attempt = 0; attempt < launch_attempts; ++attempt) {
      parent_group_verified = false;
      const bool merge_error = attempt % 2 != 0;
      const bext::ProcessResult result = bext::run_process(command, {}, timeout, {}, merge_error);
      if (scenario == Scenario::ChildDenied) {
        require(result.exit_code == launch_failure, "child ignored a genuine process-group failure");
        continue;
      }
      require(result.exit_code == 0, "grouped child did not finish successfully");
      if (merge_error) {
        require(result.standard_output == standard_output + standard_error && result.standard_error.empty(),
          "merged process output was not preserved");
      } else {
        require(result.standard_output == standard_output && result.standard_error == standard_error,
          "separate process output was not preserved");
      }
      if (scenario == Scenario::ParentGrouped) {
        require(parent_group_verified, "parent did not verify the requested process group");
      }
    }
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
