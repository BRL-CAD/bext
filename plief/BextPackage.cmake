bext_package(plief OUTPUT noinstall)

bext_sbom_component("plief/plief"
  UPSTREAM_URL "https://github.com/BRL-CAD/plief"
  PURL_BASE "pkg:github/BRL-CAD/plief"
  LICENSE "BSD-3-Clause AND MIT"
  LICENSE_FILE "@/plief/licenses/plief.txt"
  LICENSE_SHA256 "ed4f29cd3dfc1deb1dd17e4ee548cceaba5d590c9e401d07b96788713f633261"
  LICENSE_SOURCE_FILE "LICENSE.txt"
  LICENSE_SOURCE_SHA256 "ed4f29cd3dfc1deb1dd17e4ee548cceaba5d590c9e401d07b96788713f633261"
  REVIEWED_REVISION "16797b1845fae463eadcb9028dc57c8631bb8fcf"
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)
