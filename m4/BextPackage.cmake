bext_package(m4 OUTPUT noinstall GROUPS OSPRAY)

bext_sbom_component("m4/m4"
  UPSTREAM_URL "https://github.com/ibara/m4"
  VERSION "6.6"
  PURL "pkg:github/ibara/m4@om4-6.6"
  LICENSE "BSD-3-Clause AND BSD-2-Clause AND ISC"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "4ba37d2c2c8cacfc0eb6e4f3a6c00f1b7b0c847d6397166b4960bafcfdc218bb"
  LICENSE_COMMENT "Portable fork of OpenBSD m4 with GNU-compatible behavior used by ISPC. The consolidated LICENSE contains the file-level map and all applicable license texts."
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)
