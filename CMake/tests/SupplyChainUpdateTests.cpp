#include "SupplyChainTests.hpp"

namespace bext::tests {
namespace {

Json package_record(const std::string &component, const std::vector<std::string> &groups,
  const std::string &revision = "v1.2.3")
{
  return {{"SPDXID", "SPDXRef-Package-" + component + "-source"},
    {"name", component}, {"versionInfo", "1.2.3"},
    {"externalRefs", Json::array({{{"referenceType", "purl"},
      {"referenceLocator", "pkg:github/example/" + component + '@' + revision}}})},
    {"annotations", Json::array({{{"annotator", "Tool: bext:membership"},
      {"comment", Json({{"schemaVersion", 1}, {"component", component},
        {"groups", groups}}).dump()}}})}};
}

struct UpdateFixture {
  Context &context;
  fs::path source;
  fs::path wrapper;
  fs::path output;
  fs::path sbom_path;
  Json sbom;

  explicit UpdateFixture(Context &test_context) : context(test_context),
    source(context.root / "source"), wrapper(source / "probe"), output(context.root / "output"),
    sbom_path(context.root / "source.json"), sbom({{"spdxVersion", "SPDX-2.3"},
      {"documentNamespace", "https://example.invalid/source"},
      {"packages", Json::array({package_record("probe", {"BRLCAD", "APPLESEED"})})}})
  {
    fs::create_directories(wrapper);
    write_text(wrapper / "BextPackage.cmake", "");
  }

  Json &package()
  {
    return sbom["packages"][0];
  }

  void policy(const Json &rule)
  {
    write_json(wrapper / "UpdateChecks.json", {{"schemaVersion", 1},
      {"rules", Json::array({rule})}});
  }

  ProcessResult run(const std::vector<std::string> &extra = {}, bool online = false,
    const std::map<std::string, std::string> &environment = {})
  {
    write_json(sbom_path, sbom);
    std::vector<std::string> arguments = {"dependency-updates", "--sbom", sbom_path.u8string(),
      "--source-root", source.u8string(), "--output-dir", output.u8string(),
      "--cmake", context.cmake};
    arguments.insert(arguments.end(), extra.begin(), extra.end());
    if (online) arguments.insert(arguments.end(), {"--renovate", context.fixture});
    else arguments.push_back("--generate-only");
    return context.run_tool(arguments, environment);
  }

  Json report() const
  {
    return read_json(output / "dependency-update-report.json");
  }
};

void run_git(Context &context, const std::vector<std::string> &arguments)
{
  std::vector<std::string> command = {"git"};
  command.insert(command.end(), arguments.begin(), arguments.end());
  require_success(context.run(command), "Git fixture command");
}

}

void run_dependency_update_test(const std::string &name, Context &context)
{
  UpdateFixture fixture(context);
  if (name == "source-inputs") {
    require_success(fixture.run(), "dependency update input generation");
    const Json query = read_json(fixture.output / "dependency-updates.json").at("dependencies").at(0);
    require(query.at("packageName") == "https://github.com/example/probe.git", "unexpected update package name");
    require(query.at("currentValue") == "v1.2.3", "unexpected current release");
    require(fixture.report().at("packages").at(0).at("status") == "pending", "expected pending status");
    return;
  }
  if (name == "nonrelease-policy") {
    fixture.package()["externalRefs"][0]["referenceLocator"] =
      "pkg:github/example/probe@" + std::string(40, 'a');
    require_success(fixture.run(), "unreviewed nonrelease update check");
    require(fixture.report().at("packages").at(0).at("status") == "not_checked", "expected not_checked status");
    fixture.policy({{"source", "probe/source"}, {"kind", "manual"},
      {"reason", "Imported from a reviewed snapshot"}});
    require_success(fixture.run(), "manual import update check");
    const Json record = fixture.report().at("packages").at(0);
    require(record.at("status") == "manual_import", "expected manual_import status");
    require(contains(record.at("reason"), "reviewed snapshot"), "manual import reason was lost");
    return;
  }
  if (name == "group-selection") {
    fs::create_directories(fixture.source / "provider");
    write_text(fixture.source / "provider" / "BextPackage.cmake", "");
    fixture.sbom["packages"].push_back(package_record("provider", {"GDAL"}));
    require_success(fixture.run({"--group", "BRLCAD"}), "group update selection");
    const Json report = fixture.report();
    require(report.at("selection").at("groups") == Json::array({"BRLCAD"}), "unexpected selected groups");
    require(report.at("packages").at(0).at("groups") == Json::array({"APPLESEED", "BRLCAD"}),
      "shared group membership was lost");
    require(report.at("byGroup").size() == 1 && report.at("byGroup").contains("BRLCAD"),
      "unexpected group summary");
    const ProcessResult invalid = fixture.run({"--group", "missing"});
    require_failure(invalid, "unknown group selection");
    require(contains(invalid.standard_error, "unknown consumer group"), "missing unknown group diagnostic");
    require(!fs::exists(fixture.output / "dependency-update-report.json"), "failed selection retained a stale report");
    return;
  }
  if (name == "invalid-membership") {
    fixture.package()["annotations"][0]["comment"] = Json({{"schemaVersion", 1},
      {"component", "probe"}, {"groups", Json::array({"BRLCAD", "BRLCAD"})}}).dump();
    const ProcessResult result = fixture.run();
    require_failure(result, "duplicate group membership");
    require(contains(result.standard_error, "duplicate consumer group"), "missing duplicate group diagnostic");
    return;
  }
  if (name == "committed-gitlink") {
    run_git(context, {"-C", fixture.source.u8string(), "init", "-q"});
    run_git(context, {"-C", fixture.source.u8string(), "config", "user.name", "Fixture"});
    run_git(context, {"-C", fixture.source.u8string(), "config", "user.email", "fixture@example.invalid"});
    write_text(fixture.source / "seed", "seed");
    run_git(context, {"-C", fixture.source.u8string(), "add", "seed"});
    run_git(context, {"-C", fixture.source.u8string(), "commit", "-qm", "Seed"});
    const ProcessResult revision = context.run({"git", "-C", fixture.source.u8string(), "rev-parse", "HEAD"});
    require_success(revision, "read fixture revision");
    std::string pin = revision.standard_output;
    while (!pin.empty() && (pin.back() == '\n' || pin.back() == '\r')) pin.pop_back();
    write_text(fixture.source / ".gitmodules", "[submodule \"probe/source\"]\npath = probe/source\n"
      "url = https://example.invalid/consumed.git\n");
    run_git(context, {"-C", fixture.source.u8string(), "add", ".gitmodules"});
    run_git(context, {"-C", fixture.source.u8string(), "update-index", "--add", "--cacheinfo",
      "160000," + pin + ",probe/source"});
    run_git(context, {"-C", fixture.source.u8string(), "commit", "-qm", "Pin source"});
    fixture.package()["externalRefs"][0]["referenceLocator"] = "pkg:github/example/probe@" + pin;
    fixture.policy({{"source", "probe/source"}, {"kind", "commit"}, {"branch", "main"}});
    require_success(fixture.run({}, true), "committed Gitlink update check");
    const Json record = fixture.report().at("packages").at(0);
    require(record.at("query").at("packageName") == "https://example.invalid/consumed.git",
      "Gitlink URL was not selected");
    require(record.at("query").at("currentDigest") == pin, "Gitlink revision was not selected");
    require(record.at("status") == "commit_current", "expected commit_current status");
    return;
  }
  if (name == "online-candidates") {
    require_success(fixture.run({}, true, {{"BEXT_FIXTURE_RENOVATE_MODE", "updates"}}),
      "online dependency update report");
    const Json report = fixture.report();
    require(report.at("status") == "complete", "expected complete report");
    require(report.at("packages").at(0).at("status") == "updates_available", "expected update candidate");
    require(report.at("candidates").at("topLevelReleases") == 1, "expected one top-level release");
    require(contains(read_text(fixture.output / "dependency-update-report.txt"), "v9.0.0"),
      "text report omitted candidate");
    const std::string csv = read_text(fixture.output / "dependency-update-report.csv");
    require(contains(csv, "v9.0.0") && contains(csv, "APPLESEED;BRLCAD"),
      "CSV report omitted candidate or groups");
    return;
  }
  if (name == "tool-failure") {
    require_success(fixture.run(), "initial dependency update report");
    write_json(fixture.sbom_path, fixture.sbom);
    const ProcessResult result = context.run_tool({"dependency-updates", "--sbom", fixture.sbom_path.u8string(),
      "--source-root", fixture.source.u8string(), "--output-dir", fixture.output.u8string(),
      "--renovate", (context.root / "absent").u8string(), "--cmake", context.cmake});
    require_failure(result, "missing Renovate executable");
    require(fixture.report().at("status") == "tool_unavailable", "expected tool_unavailable report");
    require(contains(result.standard_error, "npm install --prefix"), "missing Renovate setup guidance");
    return;
  }
  if (name == "failed-selection") {
    require_success(fixture.run(), "initial dependency update report");
    require_failure(fixture.run({"--group", "missing"}), "failed dependency selection");
    for (const std::string extension : {"json", "txt", "csv"}) {
      require(!fs::exists(fixture.output / ("dependency-update-report." + extension)),
        "failed selection retained stale " + extension + " report");
    }
    return;
  }
  throw std::runtime_error("unknown dependency update test " + name);
}

}
