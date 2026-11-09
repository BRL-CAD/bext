bext_package(osmesa OUTPUT install GROUPS BRLCAD)

bext_sbom_component("osmesa/osmesa"
  UPSTREAM_URL "https://github.com/starseeker/osmesa"
  PURL_BASE "pkg:github/starseeker/osmesa"
  LICENSE "MIT AND SGI-B-2.0 AND BSD-3-Clause"
  LICENSE_FILE "@/osmesa/licenses/osmesa.txt"
  LICENSE_SHA256 "1c449c96762abfed1a1820c2a4a251c84f337bab1b2f66acb17ddd2dfd18c213"
  LICENSE_SOURCE_FILE "./LICENSE"
  LICENSE_SOURCE_SHA256 "1c449c96762abfed1a1820c2a4a251c84f337bab1b2f66acb17ddd2dfd18c213"
  REVIEWED_REVISION "bfa90de454a7bf59b6ad4e9aad967771d5aa8cbe"
  LICENSE_COMMENT "The staged Mesa notice declares all three grants represented by the SPDX expression."
  PURPOSE "LIBRARY"
)
