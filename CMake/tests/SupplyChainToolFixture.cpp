#include "../json.hpp"

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;
using Json = nlohmann::json;

int main(int argc, char **argv)
{
  const std::string cyclonedx_output_prefix = "cyclonedx-json=";
  std::vector<std::string> arguments(argv + 1, argv + argc);
  if (arguments.size() == 1 && arguments.front() == "--version") {
    std::cout << "fixture-version\n";
    return 0;
  }
  const bool scanner = std::find(arguments.begin(), arguments.end(), "sbom") != arguments.end() ||
    std::any_of(arguments.begin(), arguments.end(), [](const std::string &value) { return !value.rfind("sbom:", 0); });
  if (scanner) {
    const bool filtered = std::find(arguments.begin(), arguments.end(), "--vex") != arguments.end();
    fs::path inventory_path;
    for (const std::string &argument : arguments) {
      if (!argument.rfind("sbom:", 0)) inventory_path = fs::u8path(argument.substr(5));
    }
    const auto list_packages = std::find(arguments.begin(), arguments.end(), "--list-all-pkgs");
    if (list_packages != arguments.end() && list_packages + 1 != arguments.end()) inventory_path = fs::u8path(*(list_packages + 1));
    Json packages = Json::array();
    if (!inventory_path.empty()) {
      std::ifstream input(inventory_path);
      Json inventory;
      input >> inventory;
      if (inventory.value("spdxVersion", "") == "SPDX-2.3") {
        for (const Json &package : inventory.value("packages", Json::array())) {
          std::string purl;
          for (const Json &reference : package.value("externalRefs", Json::array())) {
            if (reference.value("referenceType", "") == "purl") purl = reference.value("referenceLocator", "");
          }
          packages.push_back({{"name", package.value("name", "")}, {"version", package.value("versionInfo", "")},
            {"purl", purl}, {"id", package.value("SPDXID", "")}});
        }
      } else {
        for (const Json &package : inventory.value("components", Json::array())) {
          packages.push_back({{"name", package.value("name", "")}, {"version", package.value("version", "")},
            {"purl", package.value("purl", "")}, {"id", package.value("bom-ref", "")}});
        }
      }
    }
    if (std::getenv("BEXT_FIXTURE_EMPTY_PACKAGES")) packages.clear();
    if (const char *purl = std::getenv("BEXT_FIXTURE_PURL")) {
      for (Json &package : packages) package["purl"] = purl;
    }
    for (const std::string &argument : arguments) if (!argument.rfind(cyclonedx_output_prefix, 0)) {
      std::ofstream catalog(fs::u8path(argument.substr(cyclonedx_output_prefix.size())));
      Json components = Json::array();
      for (const Json &package : packages) components.push_back({{"bom-ref", package.at("id")},
        {"name", package.at("name")}, {"purl", package.at("purl")}});
      catalog << Json({{"components", components}}).dump();
    }
    if (std::find(arguments.begin(), arguments.end(), "sbom") != arguments.end()) {
      Json report = {{"Target", "fixture"}, {"Class", "lang-pkgs"}, {"Type", "fixture"},
        {"Packages", Json::array()}};
      for (const Json &package : packages) {
        report["Packages"].push_back({{"Identifier", {{"PURL", package.at("purl")}}}});
        if (!filtered) report["Vulnerabilities"].push_back({{"VulnerabilityID", "CVE-2026-1000"},
          {"PkgName", package.at("name")}, {"InstalledVersion", package.at("version")},
          {"PkgIdentifier", {{"PURL", package.at("purl")}}}, {"PkgID", package.at("id")}});
      }
      std::cout << Json({{"Results", Json::array({report})}}).dump();
    } else {
      Json result = {{"matches", Json::array()}, {"descriptor", {{"db", {{"built", "fixture"}, {"status", {{"path", "private"}}}}}}}};
      if (!filtered) for (const Json &package : packages) result["matches"].push_back({{"artifact", package},
        {"vulnerability", {{"id", "CVE-2026-1000"}}}});
      std::cout << result.dump();
    }
    return 0;
  }
  if (const char *log = std::getenv("BEXT_FIXTURE_LOG_FILE")) {
    std::ifstream input(log, std::ios::binary);
    std::cout << input.rdbuf();
    return 0;
  }
  std::ifstream input("dependency-updates.json");
  Json document;
  input >> document;
  Json dependencies = Json::array();
  for (const Json &query : document.at("dependencies")) {
    Json dependency = query;
    const std::string mode = std::getenv("BEXT_FIXTURE_RENOVATE_MODE")
      ? std::getenv("BEXT_FIXTURE_RENOVATE_MODE") : "current";
    if (mode == "skip") dependency["skipReason"] = "fixture skip";
    else if (mode == "updates") dependency["updates"] = Json::array({{{"newValue", "v9.0.0"}, {"newVersion", "v9.0.0"}}});
    else dependency["updates"] = Json::array();
    dependencies.push_back(dependency);
  }
  std::cout << Json({{"level", 20}, {"msg", "fixture"}, {"deps", dependencies}}).dump() << '\n';
  return 0;
}
