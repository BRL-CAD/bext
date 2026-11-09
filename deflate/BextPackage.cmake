bext_package(deflate OUTPUT install GROUPS APPLESEED)

bext_sbom_component("deflate/libdeflate"
  UPSTREAM_URL "https://github.com/ebiggers/libdeflate"
  NAME "libdeflate"
  VERSION "1.20"
  PURL "pkg:github/ebiggers/libdeflate@v1.20"
  LICENSE "MIT"
  LICENSE_FILE "COPYING"
  LICENSE_SHA256 "5d246dd2537307b80fed9ba5fdddf5d0fe7a8f023393a071182b9daed56b40fe"
)
