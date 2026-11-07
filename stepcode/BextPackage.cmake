bext_package(stepcode OUTPUT install GROUPS BRLCAD)

bext_sbom_component("stepcode/stepcode"
  UPSTREAM_URL "https://github.com/stepcode/stepcode"
  PURL_BASE "pkg:github/stepcode/stepcode"
)

bext_sbom_component("stepcode/stepcode"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "@/stepcode/licenses/stepcode.txt"
  LICENSE_SHA256 "c787486f3e1358cf1cb4456b56e00862de9c0433e7d49f5501d1289ff8bef37e"
  LICENSE_SOURCE_FILE "COPYING"
  LICENSE_SOURCE_SHA256 "c787486f3e1358cf1cb4456b56e00862de9c0433e7d49f5501d1289ff8bef37e"
  REVIEWED_REVISION "ed686ee1d9cb8bf763ab8d61ef6d417c3b45c146"
  PURPOSE "LIBRARY"
)
