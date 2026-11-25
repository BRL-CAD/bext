/*
 * Published in 2026 by the United States Government.
 * This work is in the public domain.
 */

#include "Support.hpp"
#include "Commands.hpp"

#include <iostream>
#include <map>
#include <string>

namespace {

using Command = int (*)(int, char **);

int self_test(int, char **)
{
  const std::map<std::string, std::string> vectors = {
    {"", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
    {"abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"},
    {std::string(1000, 'a'), "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3"},
  };
  for (const auto &[input, expected] : vectors) {
    if (bext::sha256(input) != expected) throw std::runtime_error("SHA-256 self-test failed");
  }
  if (bext::uuid_v5_url("https://brlcad.org/test") != "ca77ee10-8668-5f68-9ab3-2b1f8767a780") {
    throw std::runtime_error("UUIDv5 self-test failed");
  }
  const bext::Json sample = {{"z", 1}, {"a", "é"}};
  if (bext::json_text(sample) != "{\n  \"a\": \"é\",\n  \"z\": 1\n}\n") {
    throw std::runtime_error("canonical JSON self-test failed");
  }
  std::cout << "Supply-chain support self-test passed\n";
  return 0;
}

}

int main(int argc, char **argv)
{
  try {
    if (argc < 2) throw std::runtime_error("a subcommand is required");
    const std::map<std::string, Command> commands = {
      {"self-test", self_test},
      {"vex-capture", bext::vex_capture},
      {"vex-generate", bext::vex_generate},
      {"vex-scan", bext::vex_scan},
      {"dependency-updates", bext::dependency_updates},
      {"release-build", bext::release_build_command},
      {"qt-attributions", bext::qt_attributions},
      {"install-transform", bext::install_transform},
      {"sbom-project", bext::sbom_project},
      {"sbom-validate", bext::sbom_validate},
    };
    const auto command = commands.find(argv[1]);
    if (command == commands.end()) throw std::runtime_error("unknown subcommand: " + std::string(argv[1]));
    return command->second(argc, argv);
  } catch (const std::exception &exception) {
    std::cerr << "bext supply chain: " << exception.what() << '\n';
    return 1;
  }
}
