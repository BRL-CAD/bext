bext_package(boost OUTPUT install GROUPS APPLESEED)

bext_sbom_component("boost/boost"
  VERSION "1.85.0"
  REVIEWED_REVISION "2d59a4b188b6f4e9f0e7bb1eb535a0dc6900d401"
  UPSTREAM_URL "https://github.com/boostorg/boost"
  PURL_BASE "pkg:github/boostorg/boost"
)

bext_sbom_component("boost/boost"
  LICENSE "BSL-1.0"
  LICENSE_FILE "LICENSE_1_0.txt"
  LICENSE_SHA256 "c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566"
  PURPOSE "LIBRARY"
)
