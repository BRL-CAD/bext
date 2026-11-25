#include "Process.hpp"

#include <array>
#include <stdexcept>
#include <thread>

#ifdef _WIN32
#  define NOMINMAX
#  include <windows.h>
#else
#  include <cerrno>
#  include <csignal>
#  include <cstring>
#  include <fcntl.h>
#  include <sys/types.h>
#  include <sys/wait.h>
#  include <unistd.h>
#endif

namespace bext {

#ifdef _WIN32

namespace {

std::wstring wide(const std::string &value)
{
  if (value.empty()) return {};
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
    static_cast<int>(value.size()), nullptr, 0);
  if (!length) throw std::runtime_error("invalid UTF-8 process argument");
  std::wstring result(static_cast<std::size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()),
    result.data(), length);
  return result;
}

std::wstring quote(const std::wstring &argument)
{
  if (argument.find_first_of(L" \t\n\v\"") == std::wstring::npos) return argument;
  std::wstring result(1, L'\"');
  std::size_t slashes = 0;
  for (wchar_t character : argument) {
    if (character == static_cast<wchar_t>(92)) {
      ++slashes;
    } else {
      if (character == static_cast<wchar_t>(34)) result.append(slashes + 1, static_cast<wchar_t>(92));
      result.append(slashes, static_cast<wchar_t>(92));
      slashes = 0;
      result += character;
    }
  }
  result.append(slashes * 2, static_cast<wchar_t>(92));
  return result + L'\"';
}

std::string read_pipe(HANDLE pipe, const ProcessOutput &output)
{
  std::string result;
  std::array<char, 4096> buffer{};
  DWORD count = 0;
  while (ReadFile(pipe, buffer.data(), static_cast<DWORD>(buffer.size()), &count, nullptr) && count) {
    result.append(buffer.data(), count);
    if (output) output(std::string_view(buffer.data(), count));
  }
  CloseHandle(pipe);
  return result;
}

void close_handle(HANDLE &handle)
{
  if (!handle) return;
  CloseHandle(handle);
  handle = nullptr;
}

}

ProcessResult run_process(const std::vector<std::string> &arguments,
  const std::filesystem::path &working_directory, std::chrono::seconds timeout,
  const ProcessOutput &output, bool merge_error)
{
  if (arguments.empty()) throw std::runtime_error("cannot run an empty command");
  SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
  HANDLE output_read = nullptr, output_write = nullptr, error_read = nullptr, error_write = nullptr;
  if (!CreatePipe(&output_read, &output_write, &security, 0)) {
    throw std::runtime_error("unable to create process pipes");
  }
  if (!merge_error && !CreatePipe(&error_read, &error_write, &security, 0)) {
    close_handle(output_read);
    close_handle(output_write);
    throw std::runtime_error("unable to create process pipes");
  }
  if (!SetHandleInformation(output_read, HANDLE_FLAG_INHERIT, 0) ||
      (!merge_error && !SetHandleInformation(error_read, HANDLE_FLAG_INHERIT, 0))) {
    close_handle(output_read);
    close_handle(output_write);
    close_handle(error_read);
    close_handle(error_write);
    throw std::runtime_error("unable to configure process pipes");
  }
  std::wstring command;
  for (const std::string &argument : arguments) {
    if (!command.empty()) command += L' ';
    command += quote(wide(argument));
  }
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup.hStdOutput = output_write;
  startup.hStdError = merge_error ? output_write : error_write;
  PROCESS_INFORMATION process{};
  HANDLE job = CreateJobObjectW(nullptr, nullptr);
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION job_limits{};
  job_limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation,
      &job_limits, sizeof(job_limits))) {
    close_handle(job);
    close_handle(output_read); close_handle(output_write);
    close_handle(error_read); close_handle(error_write);
    throw std::runtime_error("unable to create process job");
  }
  std::wstring directory = working_directory.empty() ? std::wstring() : working_directory.wstring();
  const BOOL created = CreateProcessW(nullptr, command.data(), nullptr, nullptr, TRUE,
    CREATE_NO_WINDOW | CREATE_SUSPENDED, nullptr, directory.empty() ? nullptr : directory.c_str(), &startup, &process);
  if (!created) {
    close_handle(job);
    close_handle(output_write); close_handle(error_write);
    close_handle(output_read);
    close_handle(error_read);
    throw std::runtime_error("unable to start " + arguments.front());
  }
  if (!AssignProcessToJobObject(job, process.hProcess) || ResumeThread(process.hThread) == static_cast<DWORD>(-1)) {
    TerminateJobObject(job, 1);
    CloseHandle(process.hThread); CloseHandle(process.hProcess);
    close_handle(job);
    close_handle(output_write); close_handle(error_write);
    close_handle(output_read); close_handle(error_read);
    throw std::runtime_error("unable to configure process job");
  }
  close_handle(output_write);
  close_handle(error_write);
  std::string standard_output, standard_error;
  std::thread output_reader([&] { standard_output = read_pipe(output_read, output); });
  std::thread error_reader;
  if (!merge_error) error_reader = std::thread([&] { standard_error = read_pipe(error_read, {}); });
  const DWORD wait = timeout == std::chrono::seconds::zero() ? INFINITE :
    static_cast<DWORD>(std::chrono::duration_cast<std::chrono::milliseconds>(timeout).count());
  if (WaitForSingleObject(process.hProcess, wait) == WAIT_TIMEOUT) {
    TerminateJobObject(job, 1);
    WaitForSingleObject(process.hProcess, INFINITE);
    close_handle(job);
    output_reader.join();
    if (error_reader.joinable()) error_reader.join();
    CloseHandle(process.hThread); CloseHandle(process.hProcess);
    throw std::runtime_error(arguments.front() + " exceeded its timeout");
  }
  DWORD exit_code = 1;
  GetExitCodeProcess(process.hProcess, &exit_code);
  close_handle(job);
  output_reader.join();
  if (error_reader.joinable()) error_reader.join();
  CloseHandle(process.hThread); CloseHandle(process.hProcess);
  return {static_cast<int>(exit_code), standard_output, standard_error};
}

#else

namespace {

std::string read_descriptor(int descriptor, const ProcessOutput &output)
{
  std::string result;
  std::array<char, 4096> buffer{};
  ssize_t count = 0;
  while ((count = read(descriptor, buffer.data(), buffer.size())) > 0) {
    result.append(buffer.data(), static_cast<std::size_t>(count));
    if (output) output(std::string_view(buffer.data(), static_cast<std::size_t>(count)));
  }
  close(descriptor);
  return result;
}

}


ProcessResult run_process(const std::vector<std::string> &arguments,
  const std::filesystem::path &working_directory, std::chrono::seconds timeout,
  const ProcessOutput &output, bool merge_error)
{
  if (arguments.empty()) throw std::runtime_error("cannot run an empty command");
  int output_pipe[2], error_pipe[2];
  if (pipe(output_pipe)) throw std::runtime_error("unable to create process pipes");
  if (!merge_error && pipe(error_pipe)) {
    close(output_pipe[0]);
    close(output_pipe[1]);
    throw std::runtime_error("unable to create process pipes");
  }
  const pid_t process = fork();
  if (process < 0) {
    close(output_pipe[0]);
    close(output_pipe[1]);
    if (!merge_error) { close(error_pipe[0]); close(error_pipe[1]); }
    throw std::runtime_error("unable to fork process");
  }
  if (!process) {
    if (setpgid(0, 0)) _exit(127);
    dup2(output_pipe[1], STDOUT_FILENO);
    dup2(merge_error ? output_pipe[1] : error_pipe[1], STDERR_FILENO);
    close(output_pipe[0]); close(output_pipe[1]);
    if (!merge_error) { close(error_pipe[0]); close(error_pipe[1]); }
    if (!working_directory.empty() && chdir(working_directory.c_str())) _exit(127);
    std::vector<char *> command;
    command.reserve(arguments.size() + 1);
    for (const std::string &argument : arguments) command.push_back(const_cast<char *>(argument.c_str()));
    command.push_back(nullptr);
    execvp(command.front(), command.data());
    _exit(127);
  }
  if (setpgid(process, process) && errno != EACCES && errno != ESRCH) {
    kill(process, SIGKILL);
    waitpid(process, nullptr, 0);
    close(output_pipe[0]); close(output_pipe[1]);
    if (!merge_error) { close(error_pipe[0]); close(error_pipe[1]); }
    throw std::runtime_error("unable to create process group");
  }
  close(output_pipe[1]);
  if (!merge_error) close(error_pipe[1]);
  std::string standard_output, standard_error;
  std::thread output_reader([&] { standard_output = read_descriptor(output_pipe[0], output); });
  std::thread error_reader;
  if (!merge_error) error_reader = std::thread([&] { standard_error = read_descriptor(error_pipe[0], {}); });
  int status = 0;
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  while (waitpid(process, &status, WNOHANG) == 0) {
    if (timeout != std::chrono::seconds::zero() && std::chrono::steady_clock::now() >= deadline) {
      kill(-process, SIGKILL); waitpid(process, &status, 0);
      output_reader.join();
      if (error_reader.joinable()) error_reader.join();
      throw std::runtime_error(arguments.front() + " exceeded its timeout");
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  kill(-process, SIGKILL);
  output_reader.join();
  if (error_reader.joinable()) error_reader.join();
  const int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
  return {exit_code, standard_output, standard_error};
}

#endif

}
