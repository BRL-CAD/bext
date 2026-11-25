#include "Commands.hpp"
#include "Maintenance.hpp"

#include <algorithm>
#include <iostream>
#include <map>
#include <regex>
#include <set>
#include <string>
#include <vector>

namespace bext {
namespace {

constexpr int default_scan_timeout = 1800;

std::vector<std::string> purls(const Json &package)
{
  std::vector<std::string> result;
  for (const Json &reference : package.value("externalRefs", Json::array())) {
    if (reference.value("referenceType", "") == "purl") result.push_back(reference.at("referenceLocator"));
  }
  return result;
}

void collect_components(const Json &components, std::vector<Json> &result)
{
  for (const Json &component : components) {
    result.push_back(component);
    collect_components(component.value("components", Json::array()), result);
  }
}

std::string lookup_identity(const std::string &purl)
{
  if (purl.rfind("pkg:github/", 0)) return purl;
  const std::size_t revision = purl.find('@');
  std::string result = purl.substr(0, revision);
  std::transform(result.begin(), result.end(), result.begin(), [](unsigned char character) {
    return static_cast<char>(std::tolower(character));
  });
  return result + (revision == std::string::npos ? std::string() : purl.substr(revision));
}

Json inventory_packages(const Json &document)
{
  Json packages = Json::array();
  if (document.value("spdxVersion", "") == "SPDX-2.3") {
    for (const Json &package : document.at("packages")) {
      packages.push_back({{"id", package.at("SPDXID")}, {"name", package.at("name")}, {"purls", purls(package)}});
    }
  } else if (document.value("bomFormat", "") == "CycloneDX") {
    std::vector<Json> components;
    collect_components(document.value("components", Json::array()), components);
    for (const Json &component : components) {
      Json identities = Json::array();
      if (component.contains("purl")) identities.push_back(component.at("purl"));
      packages.push_back({{"id", component.at("bom-ref")}, {"name", component.at("name")}, {"purls", identities}});
    }
  } else {
    throw std::runtime_error("expected an SPDX or CycloneDX inventory");
  }
  return packages;
}

Json scan_coverage(const Json &inventory, const std::set<std::string> &recognized_values)
{
  std::set<std::string> recognized;
  for (const std::string &purl : recognized_values) if (!purl.empty()) recognized.insert(lookup_identity(purl));
  const Json packages = inventory_packages(inventory);
  Json missing = Json::array();
  for (const Json &package : packages) {
    bool found = false;
    for (const std::string &purl : package.at("purls")) found = found || recognized.count(lookup_identity(purl));
    if (!found) missing.push_back(package);
  }
  const std::size_t total = packages.size();
  return {{"inputPackages", total}, {"recognizedPackages", total - missing.size()},
          {"unrecognizedPackages", missing},
          {"status", total == 0 ? "empty" : missing.empty() ? "complete" : "partial"},
          {"note", "Package recognition does not establish advisory coverage or absence of vulnerabilities."}};
}

std::string package_lookup(const Json &package, bool spdx)
{
  std::string purl;
  if (spdx) { const auto identities = purls(package); if (!identities.empty()) purl = identities.front(); }
  else purl = package.value("purl", "");
  const std::size_t suffix = purl.find_first_of("?#");
  const std::string body = purl.substr(0, suffix);
  const std::size_t version = body.rfind('@');
  return version == std::string::npos ? body : body.substr(0, version);
}

std::vector<fs::path> trivy_partitions(const Json &document, const fs::path &directory)
{
  const bool spdx = document.value("spdxVersion", "") == "SPDX-2.3";
  Json packages;
  if (spdx) packages = document.at("packages");
  else if (document.value("bomFormat", "") == "CycloneDX") packages = document.value("components", Json::array());
  else throw std::runtime_error("expected an SPDX or CycloneDX inventory");
  std::map<std::pair<std::string, std::string>, std::vector<Json>> groups;
  for (const Json &package : packages) {
    const std::string lookup = package_lookup(package, spdx);
    groups[{lookup.empty() ? package.at("name").get<std::string>() : lookup,
      package.value(spdx ? "versionInfo" : "version", "")}].push_back(package);
  }
  std::size_t count = 1;
  for (const auto &group : groups) count = std::max(count, group.second.size());
  if (count == 1) return {};
  std::vector<fs::path> outputs;
  for (std::size_t index = 0; index < count; ++index) {
    Json part = document;
    Json selected = Json::array();
    std::set<std::string> identifiers;
    for (const auto &group : groups) {
      const Json package = group.second.at(index % group.second.size());
      selected.push_back(package);
      identifiers.insert(package.at(spdx ? "SPDXID" : "bom-ref"));
    }
    if (spdx) {
      part["packages"] = selected;
      part["documentNamespace"] = part.at("documentNamespace").get<std::string>() + "/trivy-partition/" + std::to_string(index + 1);
      part["name"] = part.at("name").get<std::string>() + "-trivy-partition-" + std::to_string(index + 1);
      Json relations = Json::array();
      for (const Json &relation : part.value("relationships", Json::array())) {
        if (identifiers.count(relation.at("relatedSpdxElement")) &&
            (identifiers.count(relation.at("spdxElementId")) || relation.at("spdxElementId") == "SPDXRef-DOCUMENT")) relations.push_back(relation);
      }
      part["relationships"] = relations;
    } else {
      part["components"] = selected;
      for (Json &component : part["components"]) {
        component.erase("components");
        Json properties = Json::array();
        for (const Json &property : component.value("properties", Json::array())) {
          if (property.value("name", "") != "bext:source:parent" || identifiers.count(property.value("value", ""))) properties.push_back(property);
        }
        component["properties"] = properties;
      }
      const std::string root = part.at("metadata").at("component").at("bom-ref");
      Json dependencies = Json::array();
      for (Json dependency : part.value("dependencies", Json::array())) if (identifiers.count(dependency.at("ref")) || dependency.at("ref") == root) {
        Json retained = Json::array();
        for (const std::string &value : dependency.value("dependsOn", Json::array())) if (identifiers.count(value)) retained.push_back(value);
        dependency["dependsOn"] = retained;
        dependencies.push_back(dependency);
      }
      part["dependencies"] = dependencies;
      part["serialNumber"] = "urn:uuid:" + uuid_v5_url(part.at("serialNumber").get<std::string>() + "/trivy-partition/" + std::to_string(index + 1));
    }
    const fs::path path = directory / ("trivy.part-" + std::to_string(index + 1) + ".sbom.json");
    write_json_atomic(path, part);
    outputs.push_back(path);
  }
  return outputs;
}

Json merge_trivy(const std::vector<Json> &documents)
{
  Json result = documents.front();
  std::map<std::string, Json> reports;
  for (const Json &document : documents) for (const Json &report : document.value("Results", Json::array())) {
    const std::string key = report.at("Target").get<std::string>() + '\n' + report.value("Class", "") + '\n' + report.value("Type", "");
    if (!reports.count(key)) { reports[key] = report; continue; }
    for (const char *field : {"Vulnerabilities", "Packages"}) if (report.contains(field)) {
      std::map<std::string, Json> items;
      for (const Json &item : reports[key].value(field, Json::array())) items[json_text(item)] = item;
      for (const Json &item : report.at(field)) items[json_text(item)] = item;
      reports[key][field] = Json::array();
      for (const auto &item : items) reports[key][field].push_back(item.second);
    }
  }
  result["Results"] = Json::array();
  for (const auto &report : reports) result["Results"].push_back(report.second);
  return result;
}

std::string finding_key(const Json &finding)
{
  return finding.at("vulnerability").get<std::string>() + '\n' + finding.at("package").get<std::string>() + '\n' +
    finding.at("version").get<std::string>() + '\n' + finding.at("purl").get<std::string>() + '\n' + finding.at("id").get<std::string>();
}

std::map<std::string, Json> findings(const std::string &scanner, const Json &document)
{
  std::map<std::string, Json> result;
  if (scanner == "grype") {
    for (const Json &match : document.at("matches")) {
      const Json &package = match.at("artifact");
      Json record = {{"vulnerability", match.at("vulnerability").at("id")}, {"package", package.at("name")},
        {"version", package.at("version")}, {"purl", package.value("purl", "")}, {"id", package.at("id")}};
      result[finding_key(record)] = record;
    }
  } else {
    for (const Json &report : document.value("Results", Json::array())) {
      for (const Json &vulnerability : report.value("Vulnerabilities", Json::array())) {
        const Json identifier = vulnerability.value("PkgIdentifier", Json::object());
        Json record = {{"vulnerability", vulnerability.at("VulnerabilityID")}, {"package", vulnerability.at("PkgName")},
          {"version", vulnerability.at("InstalledVersion")}, {"purl", identifier.value("PURL", "")},
          {"id", vulnerability.value("PkgID", "")}};
        result[finding_key(record)] = record;
      }
    }
  }
  return result;
}

std::vector<std::string> scanner_command(const std::string &cmake, const std::string &scanner,
  const std::string &executable,
  bool disable_updates, const std::vector<std::string> &arguments)
{
  const std::vector<std::string> unset = {
    "GRYPE_VEX_DOCUMENTS", "GRYPE_VEX_ADD", "GRYPE_IGNORE", "GRYPE_ONLY_FIXED",
    "GRYPE_ONLY_NOTFIXED", "GRYPE_IGNORE_STATES", "GRYPE_FAIL_ON_SEVERITY", "TRIVY_VEX",
    "TRIVY_IGNORE_UNFIXED", "TRIVY_IGNORE_STATUS", "TRIVY_IGNORE_POLICY", "TRIVY_SEVERITY", "TRIVY_EXIT_CODE"};
  std::map<std::string, std::string> environment = {{"GRYPE_CHECK_FOR_APP_UPDATE", "false"}};
  if (scanner == "grype" && disable_updates) environment["GRYPE_DB_AUTO_UPDATE"] = "false";
  std::vector<std::string> command = {executable};
  command.insert(command.end(), arguments.begin(), arguments.end());
  return sanitized_environment_command(cmake, unset, environment, command);
}

std::set<std::string> recognized_packages(const std::string &scanner,
  const Json &raw, const fs::path &directory)
{
  std::set<std::string> result;
  if (scanner == "grype") {
    std::vector<Json> components;
    collect_components(read_json(directory / "grype.packages.cdx.json").value("components", Json::array()), components);
    for (const Json &component : components) if (component.contains("purl")) result.insert(component.at("purl"));
  } else {
    for (const Json &report : raw.value("Results", Json::array())) for (const Json &package : report.value("Packages", Json::array())) {
      const Json identifier = package.value("Identifier", Json::object());
      if (identifier.contains("PURL")) result.insert(identifier.at("PURL"));
    }
  }
  return result;
}

std::pair<Json, Json> run_scans(const std::string &cmake, const std::string &scanner,
  const std::string &executable,
  const std::vector<fs::path> &partitions, const fs::path &vex, const fs::path &directory,
  const fs::path &temporary, bool offline, int timeout)
{
  std::vector<Json> by_mode[2];
  for (std::size_t index = 0; index < partitions.size(); ++index) for (int mode = 0; mode != 2; ++mode) {
    const bool filtered = mode != 0;
    const std::string label = filtered ? "filtered" : "raw";
    const std::string stem = partitions.size() == 1 ? scanner : scanner + ".part-" + std::to_string(index + 1);
    const fs::path result_path = directory / (stem + "." + label + ".json");
    if (filtered && !fs::is_regular_file(vex)) {
      fs::copy_file(directory / (stem + ".raw.json"), result_path, fs::copy_options::overwrite_existing);
      by_mode[1].push_back(by_mode[0].back());
      continue;
    }
    std::vector<std::string> arguments;
    if (scanner == "grype") {
      arguments = {"--config", (temporary / "config.json").u8string(), "-o", "json",
        "sbom:" + partitions[index].u8string()};
      if (!filtered) arguments.insert(arguments.end(), {"--output", "cyclonedx-json=" + (directory / "grype.packages.cdx.json").u8string()});
    } else {
      arguments = {"--config", (temporary / "config.json").u8string(), "sbom", "--ignorefile",
        (temporary / "ignore").u8string(), "--format", "json", "--list-all-pkgs", partitions[index].u8string()};
      if (offline || filtered || index) arguments.insert(arguments.end(), {"--skip-db-update", "--skip-java-db-update"});
    }
    if (filtered) arguments.insert(arguments.end(), {"--vex", vex.u8string()});
    const ProcessResult process = run_process(scanner_command(cmake, scanner, executable, offline || filtered, arguments),
      {}, std::chrono::seconds(timeout));
    write_text_atomic(result_path, process.standard_output);
    write_text_atomic(directory / (stem + "." + label + ".log"), process.standard_error);
    if (process.exit_code) throw std::runtime_error(scanner + " failed; see " + stem + "." + label + ".log");
    by_mode[mode].push_back(read_json(result_path));
  }
  Json raw = by_mode[0].size() == 1 ? by_mode[0].front() : merge_trivy(by_mode[0]);
  Json filtered = by_mode[1].size() == 1 ? by_mode[1].front() : merge_trivy(by_mode[1]);
  if (partitions.size() > 1) {
    write_json_atomic(directory / (scanner + ".raw.json"), raw);
    write_json_atomic(directory / (scanner + ".filtered.json"), filtered);
  }
  return {raw, filtered};
}

Json scan_summary(const std::string &scanner, const std::string &version, const Json &inventory,
  const fs::path &input, const fs::path &vex, const fs::path &directory,
  const std::vector<fs::path> &partitions, const Json &raw, const Json &filtered)
{
  const auto baseline = findings(scanner, raw), retained = findings(scanner, filtered);
  const Json vex_document = fs::is_regular_file(vex) ? read_json(vex) : Json(nullptr);
  Json suppressed = Json::array(), added = Json::array();
  for (const auto &item : baseline) if (!retained.count(item.first)) {
    Json record = item.second;
    record["vexStatements"] = Json::array();
    if (!vex_document.is_null()) for (const Json &statement : vex_document.at("statements")) {
      bool product = false;
      for (const Json &candidate : statement.at("products")) {
        product = product || lookup_identity(candidate.at("@id")) == lookup_identity(record.at("purl"));
      }
      if (statement.at("vulnerability").value("name", "") == record.at("vulnerability") && product) {
        record["vexStatements"].push_back(statement);
      }
    }
    suppressed.push_back(record);
  }
  for (const auto &item : retained) if (!baseline.count(item.first)) added.push_back(item.second);
  const Json coverage = scan_coverage(inventory, recognized_packages(scanner, raw, directory));
  Json database = version;
  if (scanner == "grype") {
    database = raw.value("descriptor", Json::object()).value("db", Json(nullptr));
    if (database.is_object() && database.value("status", Json()).is_object()) database["status"].erase("path");
  }
  return {{"scanner", scanner}, {"toolVersion", version},
    {"testedVersion", scanner == "grype" ? "0.121.2" : "0.76.2"}, {"database", database},
    {"coverage", coverage}, {"status", coverage.at("inputPackages") != 0 && coverage.at("recognizedPackages") == 0 ? "incomplete" : "complete"},
    {"checkedAt", utc_now()}, {"vexApplied", !vex_document.is_null()},
    {"vexSha256", vex_document.is_null() ? Json(nullptr) : Json(file_sha256(vex))}, {"inputSha256", file_sha256(input)},
    {"partitions", partitions.size()}, {"rawMatches", baseline.size()}, {"filteredMatches", retained.size()},
    {"suppressed", suppressed}, {"added", added}};
}

}

int vex_scan(int argc, char **argv)
{
  const fs::path input = fs::u8path(required_option(argc, argv, "--input"));
  const fs::path output = fs::u8path(required_option(argc, argv, "--output-dir"));
  const fs::path vex = option(argc, argv, "--vex") ? fs::u8path(*option(argc, argv, "--vex")) : fs::path();
  const std::string scanner = option(argc, argv, "--scanner").value_or("grype");
  const std::string executable = option(argc, argv, "--scanner-executable").value_or(scanner);
  const std::string cmake = option(argc, argv, "--cmake").value_or("cmake");
  if (scanner != "grype" && scanner != "trivy") throw std::runtime_error("scanner must be grype or trivy");
  const int timeout = std::stoi(option(argc, argv, "--timeout").value_or(std::to_string(default_scan_timeout)));
  if (timeout <= 0) throw std::runtime_error("timeout must be positive seconds");
  fs::create_directories(output);
  const std::regex owned(scanner + R"(\.(summary\.json|packages\.cdx\.json|(?:part-[0-9]+\.)?(?:(?:raw|filtered)\.(?:json|log)|sbom\.json)))");
  for (const fs::path &path : {input, vex}) if (!path.empty() && resolved_path(path).parent_path() == resolved_path(output) &&
      std::regex_match(path.filename().u8string(), owned)) throw std::runtime_error("scan inputs must be separate from outputs");
  for (const fs::directory_entry &entry : fs::directory_iterator(output)) {
    if (std::regex_match(entry.path().filename().u8string(), owned)) fs::remove(entry.path());
  }
  const Json inventory = read_json(input);
  std::vector<fs::path> partitions;
  if (scanner == "trivy") partitions = trivy_partitions(inventory, output);
  if (partitions.empty()) partitions.push_back(input);
  const fs::path temporary = output / ("scanner-native-" + sha256(input.u8string() + utc_now()).substr(0, 16));
  fs::create_directories(temporary);
  write_text_atomic(temporary / "config.json", "{}\n");
  write_text_atomic(temporary / "ignore", "");
  Json raw, filtered;
  try {
    std::tie(raw, filtered) = run_scans(cmake, scanner, executable, partitions, vex, output, temporary,
      flag(argc, argv, "--offline"), timeout);
    fs::remove_all(temporary);
  } catch (...) {
    std::error_code error;
    fs::remove_all(temporary, error);
    throw;
  }
  const std::string version = tool_version(fs::u8path(executable));
  const Json summary = scan_summary(scanner, version, inventory, input, vex, output, partitions, raw, filtered);
  publish_files(output, {{scanner + ".summary.json", json_text(summary)}}, scanner + ".summary.json");
  std::cout << scanner << ": " << summary.at("rawMatches") << " baseline, "
            << summary.at("filteredMatches") << " after VEX, " << summary.at("suppressed").size() << " suppressed\n";
  std::cout << "Package recognition: " << summary.at("coverage").at("recognizedPackages") << '/'
            << summary.at("coverage").at("inputPackages") << "; see the summary for coverage gaps\n";
  return summary.at("status") == "complete" ? 0 : 1;
}

}
