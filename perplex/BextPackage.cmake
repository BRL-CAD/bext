bext_package(perplex OUTPUT noinstall GROUPS BRLCAD)

bext_sbom_component("perplex/perplex"
  UPSTREAM_URL "https://github.com/BRL-CAD/perplex"
  PURL_BASE "pkg:github/BRL-CAD/perplex"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "8e4926056df53b0ff61f4f55a71705ae046632b507d098770085960660cf132f"
)
