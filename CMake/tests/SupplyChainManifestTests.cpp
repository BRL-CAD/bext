#include "SupplyChainTests.hpp"

namespace bext::tests {
namespace {

Json manifest()
{
  return {{"schema", "https://brlcad.org/schema/bext-component-manifest-v2"},
    {"platform", "fixture"}, {"install_root", "install"}, {"generated_by", "bext"},
    {"files", Json::array({{{"path", "lib/probe"}, {"component", "probe"}}})},
    {"packages", Json::array({{{"component", "probe"}, {"id", "probe/source"},
      {"spdx_id", "SPDXRef-Package-probe-source"}, {"primary", true}, {"output", "install"}}})}};
}

ProcessResult validate(Context &context, const Json &document, const std::string &label)
{
  const fs::path path = context.root / (label + ".json");
  write_json(path, document);
  return context.run_tool({"sbom-validate", "--component-manifest", path.u8string()});
}

}

void run_component_manifest_test(const std::string &name, Context &context)
{
  if (name == "output-scopes") {
    for (const std::string output : {"install", "noinstall"}) {
      Json document = manifest();
      document["packages"][0]["output"] = output;
      require_success(validate(context, document, output), "component manifest " + output + " scope");
    }
    return;
  }
  if (name == "invalid-output") {
    Json missing = manifest(); missing["packages"][0].erase("output");
    require_failure(validate(context, missing, "missing"), "missing output scope");
    Json typo = manifest(); typo["packages"][0]["output"] = "typo";
    require_failure(validate(context, typo, "typo"), "unknown output scope");
    Json null = manifest(); null["packages"][0]["output"] = nullptr;
    require_failure(validate(context, null, "null"), "null output scope");
    return;
  }
  if (name == "remapping") {
    Json document = manifest();
    document["generated_by"] = "brlcad";
    document["packages"][0]["source_spdx_id"] = document["packages"][0]["spdx_id"];
    document["packages"][0]["spdx_id"] = "SPDXRef-imported";
    require_success(validate(context, document, "remapped"), "downstream package remapping");
    document["packages"][0]["source_spdx_id"] = "invalid identity";
    require_failure(validate(context, document, "invalid-remapping"), "invalid source identity");
    return;
  }
  throw std::runtime_error("unknown component manifest test " + name);
}

}
