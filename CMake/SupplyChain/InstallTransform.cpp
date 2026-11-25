/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include "Commands.hpp"
#include "Support.hpp"

#include <algorithm>
#include <cctype>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <tuple>
#include <vector>

namespace bext {
namespace {

constexpr int schema_version = 1;
const std::regex component_pattern("[a-z][a-z0-9_-]*");
const std::regex hash_pattern("[0-9a-f]{64}");

using Receipt = std::tuple<std::string, std::string, std::string, std::string>;

bool is_hash(const Json &value)
{
  return value.is_string() && std::regex_match(value.get<std::string>(), hash_pattern);
}

std::string path_key(const fs::path &path)
{
  std::string result = resolved_path(path).generic_u8string();
#ifdef _WIN32
  std::transform(result.begin(), result.end(), result.begin(),
    [](unsigned char character) { return static_cast<char>(std::tolower(character)); });
#endif
  return result;
}

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

std::set<Receipt> postprocess_receipts(const fs::path &directory)
{
  std::set<Receipt> result;
  for (const fs::directory_entry &entry : fs::directory_iterator(directory)) {
    if (!entry.is_regular_file() || entry.path().extension() != ".receipt") continue;
    const std::vector<std::string> fields = lines(entry.path());
    if (fields.size() != 5 || !std::regex_match(fields[2], hash_pattern) ||
        !std::regex_match(fields[3], hash_pattern) ||
        (fields[4].rfind("binary-postprocess|", 0) != 0 &&
         fields[4].rfind("strclear-replace|", 0) != 0)) {
      throw std::runtime_error("invalid install postprocess receipt: " + entry.path().filename().u8string());
    }
    result.emplace(path_key(fs::u8path(fields[0])), path_key(fs::u8path(fields[1])),
      fields[2], fields[3]);
  }
  return result;
}

Json exported_components(const Json &document)
{
  if (!document.is_object() || document.value("schemaVersion", 0) != schema_version ||
      !document.contains("components") || !document.at("components").is_array()) {
    throw std::runtime_error("unsupported exported VEX evidence");
  }
  Json result = Json::object();
  for (const Json &entry : document.at("components")) {
    if (!entry.is_object() || !entry.contains("component") || !entry.at("component").is_string() ||
        !entry.contains("files") || !entry.at("files").is_array()) {
      throw std::runtime_error("invalid exported component evidence");
    }
    const std::string component = entry.at("component");
    if (!std::regex_match(component, component_pattern) || result.contains(component)) {
      throw std::runtime_error("duplicate or invalid exported component: " + component);
    }
    std::set<std::string> names;
    for (const Json &artifact : entry.at("files")) {
      if (!artifact.is_object() || !artifact.contains("path") || !artifact.contains("sha256") ||
          !is_hash(artifact.at("sha256"))) {
        throw std::runtime_error("invalid exported artifact for " + component);
      }
      const std::string name = relative_name(artifact.at("path").get<std::string>());
      if (!names.insert(name).second) throw std::runtime_error("duplicate exported artifact: " + name);
    }
    result[component] = entry;
  }
  return result;
}

Json capture(const fs::path &evidence_path, const fs::path &stage_root,
  const fs::path &install_root, const fs::path &stamp_dir,
  const fs::path &postprocess, const fs::path &privacy, const fs::path &helper)
{
  const Json evidence = exported_components(read_json(evidence_path));
  const std::set<Receipt> receipts = postprocess_receipts(stamp_dir);
  Json records = Json::array();
  for (auto component = evidence.begin(); component != evidence.end(); ++component) {
    for (const Json &artifact : component.value().at("files")) {
      const std::string name = relative_name(artifact.at("path").get<std::string>());
      const fs::path source = inside(stage_root, name);
      const fs::path installed = inside(install_root, name);
      if (!fs::is_regular_file(source) || !fs::is_regular_file(installed)) continue;
      const std::string source_hash = file_sha256(source);
      if (source_hash != artifact.at("sha256")) continue;
      const std::string installed_hash = file_sha256(installed);
      const Receipt receipt(path_key(source), path_key(installed), source_hash, installed_hash);
      if (installed_hash != source_hash && !receipts.count(receipt)) continue;
      records.push_back({{"component", component.key()}, {"path", name},
        {"sourceSha256", source_hash}, {"beforeSha256", installed_hash}});
    }
  }
  return {{"schemaVersion", schema_version}, {"sourceEvidenceSha256", file_sha256(evidence_path)},
    {"pipeline", {{"installPostprocess", file_sha256(postprocess)},
                  {"installPrivacy", file_sha256(privacy)},
                  {"captureHelper", file_sha256(helper)}}},
    {"files", records}};
}

void validate_snapshot(const Json &snapshot)
{
  if (!snapshot.is_object() || snapshot.value("schemaVersion", 0) != schema_version ||
      !snapshot.contains("sourceEvidenceSha256") || !is_hash(snapshot.at("sourceEvidenceSha256")) ||
      !snapshot.contains("pipeline") || !snapshot.at("pipeline").is_object() ||
      !snapshot.contains("files") || !snapshot.at("files").is_array()) {
    throw std::runtime_error("invalid install transformation snapshot");
  }
  const Json &pipeline = snapshot.at("pipeline");
  for (const char *step : {"installPostprocess", "installPrivacy", "captureHelper"}) {
    if (!pipeline.contains(step) || !is_hash(pipeline.at(step))) {
      throw std::runtime_error("invalid install transformation pipeline");
    }
  }
  std::set<std::pair<std::string, std::string>> records;
  for (const Json &record : snapshot.at("files")) {
    if (!record.is_object() || !record.contains("component") || !record.at("component").is_string() ||
        !std::regex_match(record.at("component").get<std::string>(), component_pattern) ||
        !record.contains("path") || !record.contains("sourceSha256") ||
        !record.contains("beforeSha256") || !is_hash(record.at("sourceSha256")) ||
        !is_hash(record.at("beforeSha256"))) {
      throw std::runtime_error("invalid install transformation record");
    }
    const auto key = std::make_pair(record.at("component").get<std::string>(),
      relative_name(record.at("path").get<std::string>()));
    if (!records.insert(key).second) throw std::runtime_error("duplicate install transformation record");
  }
}

Json finalize(Json snapshot, const fs::path &evidence_path, const fs::path &install_root)
{
  validate_snapshot(snapshot);
  if (snapshot.at("sourceEvidenceSha256") != file_sha256(evidence_path)) {
    throw std::runtime_error("source evidence changed during installation");
  }
  Json records = Json::array();
  for (const Json &original : snapshot.at("files")) {
    Json record = original;
    record["sha256"] = file_sha256(inside(install_root, original.at("path").get<std::string>()));
    if (record.at("sha256") != record.at("sourceSha256")) records.push_back(std::move(record));
  }
  snapshot["files"] = std::move(records);
  return snapshot;
}

bool same_path(const fs::path &left, const fs::path &right)
{
  return path_key(left) == path_key(right);
}

}

int install_transform(int argc, char **argv)
{
  if (argc < 3) throw std::runtime_error("install-transform requires capture or finalize");
  const std::string mode = argv[2];
  if (mode != "capture" && mode != "finalize") {
    throw std::runtime_error("unknown install-transform mode: " + mode);
  }
  const fs::path evidence = fs::u8path(required_option(argc, argv, "--evidence"));
  const fs::path install_root = fs::u8path(required_option(argc, argv, "--install-root"));
  const fs::path output = fs::u8path(required_option(argc, argv, "--output"));
  const std::optional<std::string> snapshot_name = option(argc, argv, "--snapshot");
  const std::optional<std::string> stage_name = option(argc, argv, "--stage-root");
  const std::optional<std::string> stamp_name = option(argc, argv, "--stamp-dir");
  const std::optional<std::string> postprocess_name = option(argc, argv, "--postprocess");
  const std::optional<std::string> privacy_name = option(argc, argv, "--privacy");
  if (mode == "capture" && (!stage_name || !stamp_name || !postprocess_name || !privacy_name)) {
    throw std::runtime_error("capture needs --stage-root, --stamp-dir, --postprocess, and --privacy");
  }
  if (mode == "finalize" && !snapshot_name) throw std::runtime_error("finalize needs --snapshot");
  for (const std::optional<std::string> &input : {snapshot_name, postprocess_name, privacy_name}) {
    if (input && same_path(output, fs::u8path(*input))) {
      throw std::runtime_error("install evidence output must be separate from its inputs");
    }
  }
  if (same_path(output, evidence)) throw std::runtime_error("install evidence output must be separate from its inputs");
  std::error_code ignored;
  fs::remove(output, ignored);
  const Json result = mode == "capture" ?
    capture(evidence, fs::u8path(*stage_name), install_root, fs::u8path(*stamp_name),
      fs::u8path(*postprocess_name), fs::u8path(*privacy_name), fs::u8path(argv[0])) :
    finalize(read_json(fs::u8path(*snapshot_name)), evidence, install_root);
  write_json_atomic(output, result);
  return 0;
}

}
