bext_package(lz4 OUTPUT install GROUPS APPLESEED)

bext_sbom_component("lz4/lz4"
  UPSTREAM_URL "https://github.com/lz4/lz4"
  LICENSE "BSD-2-Clause AND GPL-2.0-only"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "2949fcf758d3c9bcb05f8393ca42cadfa15be04eb4ae4b3327c4ad7957511e1b"
  VERSION "1.9.4"
  PURL "pkg:github/lz4/lz4@v1.9.4"
)
