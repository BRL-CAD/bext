bext_package(zstd OUTPUT install GROUPS APPLESEED OSPRAY)

bext_sbom_component("zstd/zstd" UPSTREAM_URL "https://github.com/facebook/zstd")

bext_sbom_component("zstd/zstd"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "7055266497633c9025b777c78eb7235af13922117480ed5c674677adc381c9d8"
)

bext_sbom_component("zstd/zstd"
  VERSION "1.5.6"
  PURL "pkg:github/facebook/zstd@v1.5.6"
)
