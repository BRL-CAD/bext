#ifndef BEXT_SUPPLY_CHAIN_TESTS_HPP
#define BEXT_SUPPLY_CHAIN_TESTS_HPP

#include "../SupplyChain/Process.hpp"
#include "../json.hpp"

#include <chrono>
#include <filesystem>
#include <map>
#include <string>
#include <vector>

namespace bext::tests {

namespace fs = std::filesystem;
using Json = nlohmann::json;

struct Context {
  std::string tool;
  std::string fixture;
  std::string cmake;
  fs::path source_root;
  fs::path root;

  Context(std::string tool_path, std::string fixture_path, std::string cmake_path,
    fs::path source_path);
  ~Context();

  ProcessResult run(const std::vector<std::string> &arguments,
    const std::map<std::string, std::string> &environment = {},
    std::chrono::seconds timeout = std::chrono::seconds(120)) const;
  ProcessResult run_tool(const std::vector<std::string> &arguments,
    const std::map<std::string, std::string> &environment = {},
    std::chrono::seconds timeout = std::chrono::seconds(120)) const;
};

Json read_json(const fs::path &path);
std::string argument_value(int argc, char **argv, const std::string &name);
void write_json(const fs::path &path, const Json &value);
std::string read_text(const fs::path &path);
void write_text(const fs::path &path, const std::string &value);
void require(bool condition, const std::string &message);
void require_success(const ProcessResult &result, const std::string &operation);
void require_failure(const ProcessResult &result, const std::string &operation);
bool contains(const std::string &value, const std::string &expected);

void run_scan_report_test(const std::string &name, Context &context);
void run_dependency_update_test(const std::string &name, Context &context);
void run_component_manifest_test(const std::string &name, Context &context);
void run_filesystem_test(const std::string &name, Context &context);
void run_generation_test(const std::string &name, Context &context);
int run_vex_scanner_test(const std::string &name, Context &context);

}

#endif
