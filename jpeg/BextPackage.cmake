bext_package(jpeg OUTPUT install GROUPS APPLESEED BRLCAD GDAL)

bext_sbom_component("jpeg/libjpeg-turbo"
  UPSTREAM_URL "https://github.com/libjpeg-turbo/libjpeg-turbo"
  NAME "libjpeg-turbo"
  VERSION "3.2.0"
  PURL "pkg:github/libjpeg-turbo/libjpeg-turbo@3.2.0"
  CPE "cpe:2.3:a:libjpeg-turbo:libjpeg-turbo:3.2.0:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:libjpeg-turbo:libjpeg-turbo:0.0.90:*:*:*:*:*:*:*"
  LICENSE "IJG AND BSD-3-Clause"
  LICENSE_FILE "LICENSE.md"
  LICENSE_SHA256 "ba6bceebcba0fdd35488477c2cca8c4632ce82c74dbfbc87d886ce6fc4433579"
  LICENSE_COMMENT "Upstream states that less restrictive internal component terms are subsumed by IJG or BSD-3-Clause for the built library and tools."
  PURPOSE "LIBRARY"
)
