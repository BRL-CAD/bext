#include "Process.hpp"
#include "Commands.hpp"
#include "Support.hpp"
#include "VexCatalog.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <ctime>
#include <map>
#include <optional>
#include <regex>
#include <set>
#include <string>
#include <vector>

namespace bext {
namespace {

constexpr int schema_version = 1;

std::vector<std::string> lines(const fs::path &path)
{
  std::istringstream input(read_text(path));
  std::vector<std::string> result;
  std::string line;
  while (std::getline(input, line)) {
    if (!line.empty() && line.back() == '\r') line.pop_back();
    result.push_back(line);
  }
  return result;
}

std::string utc_now()
{
  const std::time_t now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
  std::tm utc{};
#ifdef _WIN32
  gmtime_s(&utc, &now);
#else
  gmtime_r(&now, &utc);
#endif
  std::array<char, 21> value{};
  std::strftime(value.data(), value.size(), "%Y-%m-%dT%H:%M:%SZ", &utc);
  return value.data();
}

std::string glob_regex(const std::string &pattern)
{
  std::string result = "^";
  for (std::size_t index = 0; index < pattern.size(); ++index) {
    const char character = pattern[index];
    if (character == '*') result += ".*";
    else if (character == '?') result += '.';
    else if (character == '[') {
      const std::size_t end = pattern.find(']', index + 1);
      if (end == std::string::npos) { result += static_cast<char>(92); result += '['; }
      else { result += pattern.substr(index, end - index + 1); index = end; }
    } else {
      if (std::string(".^$|(){}+\\").find(character) != std::string::npos) result += static_cast<char>(92);
      result += character;
    }
  }
  return result + '$';
}

bool glob_match(const std::string &pattern, const std::string &value)
{
  return std::regex_match(value, std::regex(glob_regex(pattern)));
}

Json source_facts(const fs::path &root, const std::string &name)
{
  const fs::path path = inside(root, name);
  const ProcessResult revision = run_process({"git", "-C", path.u8string(), "rev-parse", "HEAD"});
  const ProcessResult status = run_process({"git", "-C", path.u8string(), "status", "--porcelain", "--untracked-files=normal"});
  std::string revision_text = revision.standard_output;
  revision_text.erase(revision_text.find_last_not_of("\r\n") + 1);
  return {{"revision", revision.exit_code ? Json(nullptr) : Json(revision_text)},
          {"clean", !status.exit_code && status.standard_output.empty()}};
}

void validate_capture_catalog(const Json &catalog, const std::string &component)
{
  validate_vex_catalog(catalog, component);
}

Json capture_component(const Json &config)
{
  const std::string component = config.at("component");
  const Json catalog = read_json(fs::u8path(config.at("reviews").get<std::string>()));
  validate_capture_catalog(catalog, component);
  const fs::path source_root = resolved_path(fs::u8path(config.at("sourceRoot").get<std::string>()));
  Json inputs = Json::object();
  Json errors = Json::array();
  std::set<std::string> revisions;
  for (const std::string state_name : config.at("sourceStates")) {
    const std::vector<std::string> state = lines(fs::u8path(state_name));
    if (state.empty()) throw std::runtime_error("empty tracked source state");
    revisions.insert(state.front());
    for (auto item = state.begin() + 1; item != state.end(); ++item) {
      const std::size_t separator = item->rfind(':');
      if (separator == std::string::npos) throw std::runtime_error("invalid tracked source input");
      const fs::path path = resolved_path(fs::u8path(item->substr(0, separator)));
      if (!is_within(source_root, path)) throw std::runtime_error("tracked source input is outside the repository");
      const std::string relative = fs::relative(path, source_root).generic_string();
      const std::string expected = item->substr(separator + 1);
      const std::optional<std::string> actual = fs::is_regular_file(path) ?
        std::optional<std::string>(file_sha256(path)) : std::nullopt;
      if (!actual || *actual != expected) errors.push_back("Source input changed after configure: " + relative);
      if (inputs.contains(relative) && inputs.at(relative) != expected) {
        throw std::runtime_error("conflicting source input: " + relative);
      }
      inputs[relative] = expected;
    }
  }
  std::set<std::string> source_names, stage_names, patterns;
  for (const Json &review : catalog.at("reviews")) {
    const Json &conditions = review.at("conditions");
    for (auto item = conditions.at("sources").begin(); item != conditions.at("sources").end(); ++item) source_names.insert(item.key());
    for (auto item = conditions.at("stagedFiles").begin(); item != conditions.at("stagedFiles").end(); ++item) stage_names.insert(item.key());
    for (const Json &alternatives : conditions.at("requiredArtifacts")) {
      for (const std::string pattern : alternatives) patterns.insert(pattern);
    }
  }
  Json sources = Json::object();
  std::set<std::string> actual_revisions;
  for (const std::string &name : source_names) {
    sources[name] = source_facts(source_root, name);
    if (!sources.at(name).at("revision").is_null()) actual_revisions.insert(sources.at(name).at("revision"));
  }
  if (!std::includes(actual_revisions.begin(), actual_revisions.end(), revisions.begin(), revisions.end())) {
    errors.push_back("Tracked source revision differs from the current checkout");
  }
  const fs::path stage_root = fs::u8path(config.at("stageRoot").get<std::string>());
  Json staged = Json::object();
  for (const std::string &name : stage_names) {
    const fs::path path = inside(stage_root, name);
    staged[name] = fs::is_regular_file(path) ? Json(file_sha256(path)) : Json(nullptr);
  }
  const fs::path install_root = resolved_path(fs::u8path(config.at("installRoot").get<std::string>()));
  const fs::path build_root = fs::u8path(config.at("buildRoot").get<std::string>());
  const fs::path native_manifest = build_root / "install_manifest.txt";
  Json installed = Json::object();
  std::vector<fs::path> candidates;
  if (fs::is_regular_file(native_manifest)) {
    for (const std::string &filename : lines(native_manifest)) {
      const fs::path path = resolved_path(fs::u8path(filename));
      if (is_within(install_root, path)) candidates.push_back(path);
    }
  } else {
    for (const fs::directory_entry &entry : fs::recursive_directory_iterator(install_root)) {
      if (!entry.is_regular_file()) continue;
      const std::string name = fs::relative(entry.path(), install_root).generic_string();
      if (std::any_of(patterns.begin(), patterns.end(), [&](const std::string &pattern) { return glob_match(pattern, name); })) {
        candidates.push_back(entry.path());
      }
    }
  }
  if (fs::is_regular_file(native_manifest)) {
    for (const fs::path &path : candidates) {
      const std::string name = fs::relative(path, install_root).generic_string();
      if (fs::is_regular_file(path) && std::any_of(patterns.begin(), patterns.end(),
            [&](const std::string &pattern) { return glob_match(pattern, name); })) {
        installed[name] = file_sha256(path);
      }
    }
  } else {
    std::set<std::string> filenames, built_hashes;
    for (const fs::path &path : candidates) filenames.insert(path.filename().u8string());
    for (const fs::path &root : {build_root, stage_root}) {
      if (!fs::is_directory(root)) continue;
      for (const fs::directory_entry &entry : fs::recursive_directory_iterator(root)) {
        if (entry.is_regular_file() && filenames.count(entry.path().filename().u8string())) {
          built_hashes.insert(file_sha256(entry.path()));
        }
      }
    }
    for (const fs::path &path : candidates) {
      const std::string hash = file_sha256(path);
      if (built_hashes.count(hash)) installed[fs::relative(path, install_root).generic_string()] = hash;
    }
  }
  return {{"schemaVersion", schema_version}, {"component", component}, {"capturedAt", utc_now()},
          {"sources", sources}, {"inputs", inputs}, {"stagedFiles", staged},
          {"installedArtifacts", installed}, {"errors", errors}};
}

Json load_registry(const Json &registry)
{
  if (registry.value("schemaVersion", 0) != schema_version || !registry.at("components").is_array()) {
    throw std::runtime_error("unsupported VEX evidence registry");
  }
  Json result = Json::object();
  for (const Json &registration : registry.at("components")) {
    const std::string component = registration.at("component");
    if (result.contains(component)) throw std::runtime_error("duplicate VEX evidence component: " + component);
    const Json catalog = read_json(fs::u8path(registration.at("reviews").get<std::string>()));
    validate_capture_catalog(catalog, component);
    const fs::path evidence = fs::u8path(registration.at("evidence").get<std::string>());
    result[component] = {
      {"component", component},
      {"capture", fs::is_regular_file(evidence) ? read_json(evidence) : Json(nullptr)},
      {"reviews", catalog.at("reviews")},
    };
  }
  return result;
}

Json exported_components(const Json &document)
{
  if (document.value("schemaVersion", 0) != schema_version || !document.at("components").is_array()) {
    throw std::runtime_error("unsupported exported VEX evidence");
  }
  Json result = Json::object();
  for (const Json &entry : document.at("components")) {
    const std::string component = entry.at("component");
    if (result.contains(component)) throw std::runtime_error("duplicate exported component: " + component);
    result[component] = entry;
  }
  return result;
}

Json capture_before_finalize(const Json &registry, const fs::path &install_root,
  const std::optional<Json> &previous)
{
  Json result = Json::object();
  const Json old_components = previous ? exported_components(*previous) : Json::object();
  const Json evidence = load_registry(registry);
  for (auto entry = evidence.begin(); entry != evidence.end(); ++entry) {
    const Json &capture = entry.value().at("capture");
    if (capture.is_null()) continue;
    Json artifacts = Json::object();
    for (auto artifact = capture.at("installedArtifacts").begin();
         artifact != capture.at("installedArtifacts").end(); ++artifact) {
      const fs::path path = inside(install_root, artifact.key());
      artifacts[artifact.key()] = fs::is_regular_file(path) ? Json(file_sha256(path)) : Json(nullptr);
    }
    Json proof = {{"captureDigest", digest(capture)}, {"artifacts", artifacts}};
    if (old_components.contains(entry.key())) {
      const Json &old = old_components.at(entry.key());
      if (!old.at("capture").is_null() && digest(old.at("capture")) == digest(capture)) {
        Json old_artifacts = Json::object();
        for (const Json &artifact : old.at("files")) old_artifacts[artifact.at("path")] = artifact.at("sha256");
        proof["previous"] = {{"appliedReviews", old.at("appliedReviews")}, {"artifacts", old_artifacts}};
      }
    }
    result[entry.key()] = proof;
  }
  return {{"schemaVersion", schema_version}, {"components", result}};
}

void remove_publication(const std::optional<std::string> &name)
{
  if (!name) return;
  std::error_code error;
  fs::remove(fs::u8path(*name), error);
}

}

int vex_capture(int argc, char **argv)
{
  const std::optional<std::string> config = option(argc, argv, "--config");
  const std::optional<std::string> registry = option(argc, argv, "--before-finalize");
  if (config.has_value() == registry.has_value()) {
    throw std::runtime_error("exactly one of --config and --before-finalize is required");
  }
  const fs::path output = fs::u8path(required_option(argc, argv, "--output"));
  std::error_code error;
  fs::remove(output, error);
  Json facts;
  if (config) {
    if (option(argc, argv, "--previous-evidence") || option(argc, argv, "--previous-vex")) {
      throw std::runtime_error("previous publications apply only to --before-finalize");
    }
    facts = capture_component(read_json(fs::u8path(*config)));
  } else {
    const std::optional<std::string> previous_name = option(argc, argv, "--previous-evidence");
    std::optional<Json> previous;
    try {
      if (previous_name && fs::is_regular_file(fs::u8path(*previous_name))) previous = read_json(fs::u8path(*previous_name));
    } catch (...) {
      remove_publication(previous_name);
      remove_publication(option(argc, argv, "--previous-vex"));
      throw;
    }
    remove_publication(previous_name);
    remove_publication(option(argc, argv, "--previous-vex"));
    facts = capture_before_finalize(read_json(fs::u8path(*registry)),
      fs::u8path(required_option(argc, argv, "--install-root")), previous);
  }
  write_json_atomic(output, facts);
  return 0;
}

}
