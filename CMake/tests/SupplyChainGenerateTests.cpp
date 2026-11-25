#include "SupplyChainTests.hpp"

#include "../SupplyChain/Support.hpp"

namespace bext::tests {

void run_generation_test(const std::string &name, Context &context)
{
  if (name != "directory-symlink") throw std::runtime_error("unknown generation test " + name);
  const fs::path install = context.root / "install";
  const fs::path framework = install / "lib" / "QtConcurrent.framework";
  const fs::path headers = framework / "Versions" / "A" / "Headers";
  fs::create_directories(headers);
  std::error_code error;
  fs::create_directory_symlink("A", framework / "Versions" / "Current", error);
  if (error) {
#ifdef _WIN32
    return;
#else
    throw std::runtime_error("unable to create framework version symlink: " + error.message());
#endif
  }
  fs::create_directory_symlink("Versions/Current/Headers", framework / "Headers", error);
  if (error) throw std::runtime_error("unable to create framework headers symlink: " + error.message());

  const fs::path manifest = context.root / "manifest.json";
  write_json(manifest, {{"schema", "https://brlcad.org/schema/bext-component-manifest-v2"},
    {"platform", "fixture"}, {"files", Json::array({{{"path", "lib/QtConcurrent.framework/Headers"},
      {"component", "qt"}}})}, {"packages", Json::array({{{"spdx_id", "SPDXRef-zlib"},
      {"component", "qt"}, {"output", "install"}}})}});
  const fs::path evidence = context.root / "evidence.json";
  write_json(evidence, {{"schemaVersion", 1}, {"components", Json::array({{{"component", "qt"},
    {"capture", nullptr}, {"reviews", Json::array()}}})}});
  const fs::path output = context.root / "output";
  require_success(context.run_tool({"vex-generate", "--sbom",
    (context.source_root / "CMake" / "tests" / "fixtures" / "vulnerable-zlib.spdx.json").u8string(),
    "--manifest", manifest.u8string(), "--install-root", install.u8string(),
    "--output-dir", output.u8string(), "--import-evidence", evidence.u8string(),
    "--aliases", context.source_root.u8string(), "--product", "fixture"}),
    "directory symlink generation");
  const Json generated = read_json(output / "fixture-vex-evidence.json");
  const Json artifact = generated.at("components").front().at("files").front();
  require(artifact.at("path") == "lib/QtConcurrent.framework/Headers", "directory symlink path changed");
  require(artifact.at("linkTarget") == "lib/QtConcurrent.framework/Versions/A/Headers",
    "directory symlink target was not resolved within the bundle");
  require(artifact.at("sha256") == sha256("Versions/Current/Headers"),
    "directory symlink hash does not identify its stored target");
}

}
