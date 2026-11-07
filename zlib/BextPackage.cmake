bext_package(zlib OUTPUT install GROUPS APPLESEED BRLCAD OSPRAY TCL)

bext_sbom_component("zlib/zlib" UPSTREAM_URL "https://github.com/madler/zlib")

bext_sbom_component("zlib/zlib"
  VERSION "1.4"
  PURL "pkg:github/madler/zlib@v1.4"
  CPE "cpe:2.3:a:zlib:zlib:1.4:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:zlib:zlib:0.3:*:*:*:*:*:*:*"
)

bext_sbom_component("zlib/zlib"
  COPYRIGHT_TEXT "Copyright (C) 1995-2026 Jean-loup Gailly and Mark Adler"
  COPYRIGHT_REVIEWED_REVISION "e17eda50cea24d21f82100621eb8b1846ae13af7"
  LICENSE "Zlib"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "e32ff4e00d9d94930537635291da39e7e612703334bf6fde8c7f1686fe8a45a2"
)
