/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include "Commands.hpp"
#include "Maintenance.hpp"

#include <iostream>
#include <map>
#include <regex>
#include <set>
#include <string>

namespace bext {
namespace {

using OrderedJson = nlohmann::ordered_json;

std::string git_output(const fs::path &source, const std::vector<std::string> &arguments)
{
  std::vector<std::string> command = {"git", "-C", source.u8string()};
  command.insert(command.end(), arguments.begin(), arguments.end());
  const ProcessResult result = run_process(command);
  if (result.exit_code) throw std::runtime_error("git failed in " + source.u8string());
  return result.standard_output;
}

std::string trim_line_endings(std::string value)
{
  const std::size_t last = value.find_last_not_of("\r\n");
  return last == std::string::npos ? std::string() : value.substr(0, last + 1);
}

std::string normalize_newlines(std::string value)
{
  std::size_t position = 0;
  while ((position = value.find("\r\n", position)) != std::string::npos) {
    value.replace(position, 2, "\n");
    ++position;
  }
  return value;
}

void refresh_qt_attributions(const fs::path &package)
{
  const fs::path source = package / "qt";
  if (!fs::exists(source / ".git")) {
    throw std::runtime_error("Initialize the Qt source checkout before refreshing attribution snapshots");
  }
  const fs::path manifest_path = package / "attributions.json";
  OrderedJson manifest = OrderedJson::parse(read_text(manifest_path));
  if (!manifest.is_object() || manifest.value("schemaVersion", 0) != 1) {
    throw std::runtime_error("Unsupported Qt attribution snapshot schema");
  }
  const std::string revision = trim_line_endings(git_output(source, {"rev-parse", "--verify", "HEAD"}));
  const std::string names = git_output(source,
    {"ls-tree", "-r", "--name-only", revision, "--", "qtbase", "qtsvg"});
  std::map<std::string, std::string> critical;
  const std::regex security_critical(R"("SecurityCritical"\s*:\s*true)");
  for (const std::string &name : nonempty_lines(names)) {
    if (name.size() < 20 || name.substr(name.size() - 20) != "/qt_attribution.json") continue;
    const std::string data = normalize_newlines(git_output(source, {"show", revision + ':' + name}));
    if (!std::regex_search(data, security_critical)) continue;
    const Json document = Json::parse(data);
    const Json entries = document.is_array() ? document : Json::array({document});
    for (const Json &entry : entries) {
      if (!entry.is_object()) throw std::runtime_error("Invalid Qt attribution records: " + name);
      if (entry.value("SecurityCritical", false)) critical[name] = data;
    }
  }
  std::set<std::string> reviewed;
  for (const auto &entry : manifest.at("components")) {
    reviewed.insert("qtbase/" + entry.at("path").get<std::string>() + "/qt_attribution.json");
  }
  if (reviewed.size() != manifest.at("components").size()) {
    throw std::runtime_error("Duplicate reviewed Qt attribution paths");
  }
  std::set<std::string> discovered;
  for (const auto &entry : critical) discovered.insert(entry.first);
  if (reviewed != discovered) {
    std::vector<std::string> added, removed;
    std::set_difference(discovered.begin(), discovered.end(), reviewed.begin(), reviewed.end(), std::back_inserter(added));
    std::set_difference(reviewed.begin(), reviewed.end(), discovered.begin(), discovered.end(), std::back_inserter(removed));
    throw std::runtime_error("Review Qt component mappings before refreshing: added " +
      (added.empty() ? "none" : join_strings(added, ", ")) + "; removed " +
      (removed.empty() ? "none" : join_strings(removed, ", ")));
  }
  std::map<std::string, std::string> outputs;
  for (auto &entry : manifest.at("components")) {
    const fs::path snapshot = fs::u8path(entry.at("snapshot").get<std::string>());
    if (snapshot.filename() != snapshot || snapshot.extension() != ".json") {
      throw std::runtime_error("Invalid Qt snapshot filename: " + snapshot.u8string());
    }
    const std::string name = "qtbase/" + entry.at("path").get<std::string>() + "/qt_attribution.json";
    entry["sha256"] = sha256(critical.at(name));
    outputs[(fs::path("attributions") / snapshot).u8string()] = critical.at(name);
  }
  manifest["reviewedRevision"] = revision;
  outputs["attributions.json"] = manifest.dump(2) + '\n';
  publish_files(package, outputs, "attributions.json");
  std::cout << "Refreshed " << manifest.at("components").size()
            << " Qt attribution snapshots at " << revision
            << "; review the changes before staging.\n";
}

}

int qt_attributions(int argc, char **argv)
{
  refresh_qt_attributions(fs::u8path(required_option(argc, argv, "--package-dir")));
  return 0;
}

}
