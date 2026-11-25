bext_package(happly OUTPUT install GROUPS APPLESEED)

bext_sbom_component("happly/happly"
  UPSTREAM_URL "https://github.com/nmwsharp/happly"
  PURL_BASE "pkg:github/BRL-CAD/happly"
  LICENSE "MIT"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "7bc48d156b135363116a2d78e4c34ac9cd5932d4612a0e13b8738b3b02a621e7"
  PURPOSE "LIBRARY"
)
