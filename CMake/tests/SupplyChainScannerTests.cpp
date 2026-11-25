#include "SupplyChainTests.hpp"

#include <cstdlib>
#include <set>

namespace bext::tests {
namespace {

using Finding = std::pair<std::string, std::string>;
const std::string target_cve = "CVE-2018-25032";
const std::string control_cve = "CVE-2022-37434";
const std::string reviewed_build = "reviewed-build";
const std::string other_build = "other-build";

struct ScannerFixture {
  Context &context;
  Json inventory;
  std::string source_purl;
  fs::path vex;
  int scan_index = 0;

  explicit ScannerFixture(Context &test_context) : context(test_context),
    inventory(read_json(context.source_root / "CMake/tests/fixtures/vulnerable-zlib.spdx.json")),
    vex(context.root / "synthetic.openvex.json")
  {
    for (const Json &reference : inventory.at("packages").at(0).at("externalRefs")) {
      if (reference.at("referenceType") == "purl") source_purl = reference.at("referenceLocator");
    }
    require(!source_purl.empty(), "scanner fixture has no source PURL");
    write_json(vex, {{"@context", "https://openvex.dev/ns/v0.2.0"},
      {"@id", "https://example.invalid/vex/scanner-fixture"},
      {"author", "https://example.invalid/"}, {"timestamp", "2026-01-01T00:00:00Z"},
      {"version", 1}, {"statements", Json::array({{
        {"vulnerability", {{"name", target_cve}}},
        {"products", Json::array({{{"@id", build_purl(reviewed_build)}}})},
        {"status", "not_affected"}, {"justification", "vulnerable_code_not_present"},
        {"impact_statement", "Synthetic identity-matching fixture only. This is not an assertion about any distributed software."}
      }})}});
  }

  std::string build_purl(const std::string &build) const
  {
    return source_purl + "?bext_build=" + build;
  }

  fs::path write_inventory(const std::string &format, const std::string &build)
  {
    Json document = inventory;
    const std::string label = build.empty() ? "unqualified-source" : build;
    document["documentNamespace"] = document.at("documentNamespace").get<std::string>() + '/' + label;
    if (!build.empty()) for (Json &reference : document["packages"][0]["externalRefs"]) {
      if (reference.at("referenceType") == "purl") reference["referenceLocator"] = build_purl(build);
    }
    const fs::path spdx = context.root / (label + ".spdx.json");
    write_json(spdx, document);
    if (format == "spdx") return spdx;
    const fs::path cdx = context.root / (label + ".cdx.json");
    const fs::path script = context.root / "convert.cmake";
    write_text(script, "cmake_minimum_required(VERSION 3.26)\n"
      "include(\"${MODULE}/CMake/BextCycloneDx.cmake\")\n"
      "file(READ \"${INPUT}\" inventory)\n"
      "bext_write_cyclonedx(\"${OUTPUT}\" \"${inventory}\")\n");
    const ProcessResult result = context.run({context.cmake,
      "-DMODULE=" + context.source_root.u8string(), "-DINPUT=" + spdx.u8string(),
      "-DOUTPUT=" + cdx.u8string(), "-P", script.u8string()});
    require_success(result, "CycloneDX scanner fixture conversion");
    return cdx;
  }

  std::set<Finding> findings(const std::string &scanner, const Json &document) const
  {
    std::set<Finding> result;
    if (scanner == "grype") {
      for (const Json &match : document.at("matches")) result.emplace(
        match.at("vulnerability").at("id"), match.at("artifact").value("purl", ""));
    } else {
      for (const Json &report : document.value("Results", Json::array())) {
        for (const Json &vulnerability : report.value("Vulnerabilities", Json::array())) {
          result.emplace(vulnerability.at("VulnerabilityID"),
            vulnerability.value("PkgIdentifier", Json::object()).value("PURL", ""));
        }
      }
    }
    return result;
  }

  struct ScanResult {
    Json summary;
    std::set<Finding> raw;
    std::set<Finding> filtered;
  };

  ScanResult scan(const std::string &scanner, const fs::path &input, bool apply_vex)
  {
    const fs::path output = context.root / ("native-" + scanner + '-' + std::to_string(++scan_index));
    std::vector<std::string> arguments = {"vex-scan", "--input", input.u8string(),
      "--output-dir", output.u8string(), "--scanner", scanner, "--scanner-executable",
      scanner, "--cmake", context.cmake, "--offline"};
    if (apply_vex) arguments.insert(arguments.end(), {"--vex", vex.u8string()});
    require_success(context.run_tool(arguments, {}, std::chrono::seconds(600)), scanner + " VEX scan");
    return {read_json(output / (scanner + ".summary.json")),
      findings(scanner, read_json(output / (scanner + ".raw.json"))),
      findings(scanner, read_json(output / (scanner + ".filtered.json")))};
  }
};

bool scanner_available(Context &context, const std::string &scanner)
{
  try {
    return context.run({scanner, "--version"}, {}, std::chrono::seconds(30)).exit_code == 0;
  } catch (const std::exception &) {
    return false;
  }
}

std::set<std::string> vulnerability_ids(const std::set<Finding> &findings)
{
  std::set<std::string> result;
  for (const Finding &finding : findings) result.insert(finding.first);
  return result;
}

}

int run_vex_scanner_test(const std::string &name, Context &context)
{
  const char *enabled = std::getenv("BEXT_VEX_SCANNER_TESTS");
  if (!enabled || std::string(enabled) != "1") return 77;
  ScannerFixture fixture(context);
  if (name == "grype" || name == "trivy") {
    if (!scanner_available(context, name)) return 77;
    for (const std::string format : {"spdx", "cdx"}) {
      const fs::path reviewed = fixture.write_inventory(format, reviewed_build);
      const std::set<std::string> baseline = vulnerability_ids(fixture.scan(name, reviewed, false).raw);
      require(baseline.count(target_cve) && baseline.count(control_cve),
        "cached scanner database must detect both control CVEs");
      const std::set<std::string> filtered = vulnerability_ids(fixture.scan(name, reviewed, true).filtered);
      require(!filtered.count(target_cve), "reviewed vulnerability was not suppressed");
      require(filtered.count(control_cve), "positive control vulnerability was suppressed");
      for (const std::string build : {other_build, std::string()}) {
        const std::set<std::string> retained = vulnerability_ids(
          fixture.scan(name, fixture.write_inventory(format, build), true).filtered);
        require(retained.count(target_cve) && retained.count(control_cve),
          "VEX applied to a different build identity");
      }
    }
    return 0;
  }
  if (name == "mixed-variants") {
    bool tested = false;
    for (const std::string scanner : {"grype", "trivy"}) {
      if (!scanner_available(context, scanner)) continue;
      tested = true;
      for (const std::string format : {"spdx", "cdx"}) {
        const fs::path path = fixture.write_inventory(format, reviewed_build);
        Json document = read_json(path);
        if (format == "spdx") {
          Json other = document.at("packages").at(0);
          other["SPDXID"] = "SPDXRef-zlib-other";
          for (Json &reference : other["externalRefs"]) if (reference.at("referenceType") == "purl") {
            reference["referenceLocator"] = fixture.build_purl(other_build);
          }
          document["packages"].push_back(other);
          document["relationships"].push_back({{"spdxElementId", "SPDXRef-DOCUMENT"},
            {"relationshipType", "DESCRIBES"}, {"relatedSpdxElement", "SPDXRef-zlib-other"}});
        } else {
          Json other = document.at("components").at(0);
          other["bom-ref"] = "SPDXRef-zlib-other";
          other["purl"] = fixture.build_purl(other_build);
          document["components"].push_back(other);
          document["dependencies"].push_back({{"ref", "SPDXRef-zlib-other"},
            {"dependsOn", Json::array()}});
          const std::string root = document.at("metadata").at("component").at("bom-ref");
          for (Json &dependency : document["dependencies"]) if (dependency.at("ref") == root) {
            dependency["dependsOn"].push_back("SPDXRef-zlib-other");
          }
        }
        write_json(path, document);
        const ScannerFixture::ScanResult result = fixture.scan(scanner, path, true);
        const Finding reviewed_target = {target_cve, fixture.build_purl(reviewed_build)};
        const Finding other_target = {target_cve, fixture.build_purl(other_build)};
        require(result.raw.count(reviewed_target) && result.raw.count(other_target),
          "scanner did not report both vulnerable variants");
        require(!result.filtered.count(reviewed_target) && result.filtered.count(other_target),
          "VEX did not isolate the reviewed build variant");
        for (const std::string build : {reviewed_build, other_build}) {
          require(result.filtered.count({control_cve, fixture.build_purl(build)}),
            "positive control was removed from a build variant");
        }
        require(result.summary.at("partitions") == (scanner == "trivy" ? 2 : 1),
          "unexpected scanner partition count");
        require(result.summary.at("suppressed").size() == 1, "unexpected suppressed finding count");
        require(result.summary.at("suppressed").at(0).at("vexStatements").at(0).at("status") == "not_affected",
          "suppression did not preserve its VEX decision");
        require(!result.summary.at("vexSha256").get<std::string>().empty(), "VEX digest is empty");
      }
    }
    return tested ? 0 : 77;
  }
  throw std::runtime_error("unknown VEX scanner test " + name);
}

}
