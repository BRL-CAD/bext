bext_package(xerces-c OUTPUT install GROUPS APPLESEED)

bext_sbom_component("xerces-c/xerces-c"
  UPSTREAM_URL "https://github.com/apache/xerces-c"
  VERSION "3.2.5"
  PURL "pkg:github/apache/xerces-c@v3.2.5"
  CPE "cpe:2.3:a:apache:xerces-c\\+\\+:3.2.5:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:apache:xerces-c\\+\\+:-:*:*:*:*:*:*:*"
  LICENSE "Apache-2.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
)
