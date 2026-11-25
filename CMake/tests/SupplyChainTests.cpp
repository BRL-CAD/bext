#include "SupplyChainTests.hpp"

#include <fstream>
#include <iostream>
#include <iterator>
#include <random>
#include <stdexcept>
#include <utility>

namespace bext::tests {
namespace {

fs::path temporary_directory()
{
  std::random_device random;
  for (int attempt = 0; attempt < 100; ++attempt) {
    const fs::path candidate = fs::temp_directory_path() /
      ("bext-supply-chain-test-" + std::to_string(random()) + '-' + std::to_string(attempt));
    std::error_code error;
    if (fs::create_directory(candidate, error)) return candidate;
  }
  throw std::runtime_error("unable to create a temporary test directory");
}

}

std::string argument_value(int argc, char **argv, const std::string &name)
{
  for (int index = 1; index + 1 < argc; ++index) if (argv[index] == name) return argv[index + 1];
  throw std::runtime_error("missing " + name);
}

Context::Context(std::string tool_path, std::string fixture_path, std::string cmake_path,
  fs::path source_path) : tool(std::move(tool_path)), fixture(std::move(fixture_path)),
  cmake(std::move(cmake_path)), source_root(std::move(source_path)), root(temporary_directory())
{
}

Context::~Context()
{
  std::error_code error;
  fs::remove_all(root, error);
}

ProcessResult Context::run(const std::vector<std::string> &arguments,
  const std::map<std::string, std::string> &environment, std::chrono::seconds timeout) const
{
  if (environment.empty()) return run_process(arguments, root, timeout);
  std::vector<std::string> command = {cmake, "-E", "env"};
  for (const auto &[name, value] : environment) command.push_back(name + '=' + value);
  command.push_back("--");
  command.insert(command.end(), arguments.begin(), arguments.end());
  return run_process(command, root, timeout);
}

ProcessResult Context::run_tool(const std::vector<std::string> &arguments,
  const std::map<std::string, std::string> &environment, std::chrono::seconds timeout) const
{
  std::vector<std::string> command = {tool};
  command.insert(command.end(), arguments.begin(), arguments.end());
  return run(command, environment, timeout);
}

Json read_json(const fs::path &path)
{
  std::ifstream input(path);
  if (!input) throw std::runtime_error("unable to read " + path.u8string());
  Json value;
  input >> value;
  return value;
}

void write_json(const fs::path &path, const Json &value)
{
  fs::create_directories(path.parent_path());
  std::ofstream output(path);
  if (!output) throw std::runtime_error("unable to write " + path.u8string());
  output << value.dump(2) << '\n';
}

std::string read_text(const fs::path &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error("unable to read " + path.u8string());
  return std::string(std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>());
}

void write_text(const fs::path &path, const std::string &value)
{
  fs::create_directories(path.parent_path());
  std::ofstream output(path, std::ios::binary);
  if (!output) throw std::runtime_error("unable to write " + path.u8string());
  output << value;
}

void require(bool condition, const std::string &message)
{
  if (!condition) throw std::runtime_error(message);
}

void require_success(const ProcessResult &result, const std::string &operation)
{
  if (result.exit_code) throw std::runtime_error(operation + " failed:\n" + result.standard_error + result.standard_output);
}

void require_failure(const ProcessResult &result, const std::string &operation)
{
  if (!result.exit_code) throw std::runtime_error(operation + " unexpectedly succeeded");
}

bool contains(const std::string &value, const std::string &expected)
{
  return value.find(expected) != std::string::npos;
}

}

int main(int argc, char **argv)
{
  try {
    const std::string name = bext::tests::argument_value(argc, argv, "--case");
    bext::tests::Context context(
      bext::tests::argument_value(argc, argv, "--tool"),
      bext::tests::argument_value(argc, argv, "--fixture"),
      bext::tests::argument_value(argc, argv, "--cmake"),
      std::filesystem::u8path(bext::tests::argument_value(argc, argv, "--source-root")));
    if (!name.rfind("scan-", 0)) bext::tests::run_scan_report_test(name.substr(5), context);
    else if (!name.rfind("updates-", 0)) bext::tests::run_dependency_update_test(name.substr(8), context);
    else if (!name.rfind("manifest-", 0)) bext::tests::run_component_manifest_test(name.substr(9), context);
    else if (!name.rfind("filesystem-", 0)) bext::tests::run_filesystem_test(name.substr(11), context);
    else if (!name.rfind("generate-", 0)) bext::tests::run_generation_test(name.substr(9), context);
    else if (!name.rfind("scanner-", 0)) return bext::tests::run_vex_scanner_test(name.substr(8), context);
    else throw std::runtime_error("unknown test case " + name);
    std::cout << "Passed " << name << '\n';
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "bext_supply_chain_tests: " << error.what() << '\n';
    return 1;
  }
}
