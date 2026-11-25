bext_package(struetype OUTPUT install GROUPS APPLESEED BRLCAD)

bext_sbom_component("struetype/struetype"
  UPSTREAM_URL "https://github.com/BRL-CAD/struetype"
  PURL_BASE "pkg:github/BRL-CAD/struetype"
  LICENSE "MIT OR Unlicense"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "2e144a5ed0195ba77b860d2e3868ca58768105c8ca8efd43c8f534d730e6af6b"
  PURPOSE "LIBRARY"
)
