bext_package(expat OUTPUT install GROUPS APPLESEED)

bext_sbom_component("expat/libexpat" UPSTREAM_URL "https://github.com/libexpat/libexpat")

bext_sbom_component("expat/libexpat"
  VERSION "2.6.2"
  PURL "pkg:github/libexpat/libexpat@R_2_6_2"
  CPE "cpe:2.3:a:libexpat_project:libexpat:2.6.2:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_EXACT"
)

bext_sbom_component("expat/libexpat"
  LICENSE "MIT"
  LICENSE_FILE "COPYING"
  LICENSE_SHA256 "122f2c27000472a201d337b9b31f7eb2b52d091b02857061a8880371612d9534"
)
