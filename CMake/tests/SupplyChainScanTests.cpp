/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include "SupplyChainTests.hpp"

namespace bext::tests {
namespace {

struct ScanFixture {
  Context &context;
  fs::path inventory;
  Json source;

  explicit ScanFixture(Context &test_context) : context(test_context),
    inventory(context.root / "source.json"), source({
      {"spdxVersion", "SPDX-2.3"},
      {"packages", Json::array({{
        {"SPDXID", "SPDXRef-probe"}, {"name", "probe"}, {"versionInfo", "1.0"},
        {"externalRefs", Json::array({{{"referenceType", "purl"},
          {"referenceLocator", "pkg:conan/probe@1.0"}}})}
      }})}
    })
  {
    write_json(inventory, source);
  }

  std::pair<ProcessResult, Json> scan(const fs::path &output,
    const std::map<std::string, std::string> &environment = {})
  {
    write_json(inventory, source);
    const ProcessResult result = context.run_tool({"vex-scan", "--input", inventory.u8string(),
      "--output-dir", output.u8string(), "--scanner", "grype", "--scanner-executable",
      context.fixture, "--cmake", context.cmake, "--offline"}, environment);
    return {result, read_json(output / "grype.summary.json")};
  }
};

}

void run_scan_report_test(const std::string &name, Context &context)
{
  ScanFixture fixture(context);
  if (name == "coverage") {
    auto complete = fixture.scan(context.root / "complete");
    require_success(complete.first, "complete scanner coverage");
    require(complete.second.at("coverage").at("status") == "complete", "expected complete coverage");
    require(complete.second.at("coverage").at("recognizedPackages") == 1, "expected one recognized package");
    auto partial = fixture.scan(context.root / "partial", {{"BEXT_FIXTURE_EMPTY_PACKAGES", "1"}});
    require_failure(partial.first, "partial scanner coverage");
    require(partial.second.at("coverage").at("status") == "partial", "expected partial coverage");
    require(partial.second.at("coverage").at("unrecognizedPackages").at(0).at("id") == "SPDXRef-probe",
      "expected probe to be unrecognized");
    fixture.source["packages"] = Json::array();
    auto empty = fixture.scan(context.root / "empty", {{"BEXT_FIXTURE_EMPTY_PACKAGES", "1"}});
    require_success(empty.first, "empty scanner coverage");
    require(empty.second.at("coverage").at("status") == "empty", "expected empty coverage");
    return;
  }
  if (name == "github-case") {
    fixture.source["packages"][0]["externalRefs"][0]["referenceLocator"] =
      "pkg:github/BRL-CAD/Probe@ReleaseA";
    auto matching = fixture.scan(context.root / "matching",
      {{"BEXT_FIXTURE_PURL", "pkg:github/brl-cad/probe@ReleaseA"}});
    require_success(matching.first, "case-normalized scanner coverage");
    require(matching.second.at("coverage").at("recognizedPackages") == 1, "repository case should normalize");
    auto mismatch = fixture.scan(context.root / "mismatch",
      {{"BEXT_FIXTURE_PURL", "pkg:github/brl-cad/probe@releasea"}});
    require_failure(mismatch.first, "revision case mismatch");
    require(mismatch.second.at("coverage").at("recognizedPackages") == 0, "revision case must remain distinct");
    return;
  }
  if (name == "stale-output") {
    const fs::path output = context.root / "reports";
    fs::create_directories(output);
    for (const std::string file : {"grype.raw.json", "grype.filtered.log", "grype.summary.json"}) {
      write_text(output / file, "stale");
    }
    auto report = fixture.scan(output);
    require_success(report.first, "scanner output replacement");
    require(report.second.at("rawMatches") == 1, "expected one raw match");
    require(read_text(output / "grype.raw.json") != "stale", "stale raw output was retained");
    return;
  }
  if (name == "timeout") {
    const ProcessResult result = context.run_tool({"vex-scan", "--input", fixture.inventory.u8string(),
      "--output-dir", (context.root / "timeout").u8string(), "--timeout", "0"});
    require_failure(result, "nonpositive timeout");
    require(contains(result.standard_error, "timeout must be positive"), "missing timeout diagnostic");
    return;
  }
  throw std::runtime_error("unknown scan report test " + name);
}

}
