bext_package(robin-map OUTPUT install GROUPS APPLESEED)

bext_sbom_component("robin-map/robin-map"
  UPSTREAM_URL "https://github.com/Tessil/robin-map"
  VERSION "1.4.1"
  PURL "pkg:github/Tessil/robin-map@v1.4.1"
  LICENSE "MIT"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "11f2c685ba565a31aef1219f63a7a8845602c97bff70016b9e3278dfe51a2ec5"
  PURPOSE "LIBRARY"
)
