bext_package(opencv OUTPUT install GROUPS BRLCAD)

bext_sbom_component("opencv/opencv" UPSTREAM_URL "https://github.com/opencv/opencv")

bext_sbom_component("opencv/opencv"
  VERSION "5.0.0"
  PURL "pkg:github/opencv/opencv@5.0.0"
  CPE "cpe:2.3:a:opencv:opencv:5.0.0:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:opencv:opencv:3.3.1:*:*:*:*:*:*:*"
)

bext_sbom_component("opencv/opencv"
  LICENSE "Apache-2.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
)

bext_sbom_subcomponent("opencv/opencv" "3rdparty/zlib"
  NAME "zlib"
  VERSION "1.3.2"
  UPSTREAM_URL "https://github.com/madler/zlib"
  PURL "pkg:github/madler/zlib@v1.3.2"
  CPE "cpe:2.3:a:zlib:zlib:1.3.2:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:zlib:zlib:0.3:*:*:*:*:*:*:*"
  LICENSE "Zlib"
  LICENSE_FILE "3rdparty/zlib/LICENSE"
  LICENSE_SHA256 "e32ff4e00d9d94930537635291da39e7e612703334bf6fde8c7f1686fe8a45a2"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)

bext_sbom_subcomponent("opencv/opencv" "3rdparty/libpng"
  NAME "libpng"
  VERSION "1.6.57"
  UPSTREAM_URL "https://github.com/pnggroup/libpng"
  PURL "pkg:github/pnggroup/libpng@v1.6.57"
  CPE "cpe:2.3:a:libpng:libpng:1.6.57:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:libpng:libpng:1.6.58:*:*:*:*:*:*:*"
  LICENSE "Libpng-2.0"
  LICENSE_FILE "3rdparty/libpng/LICENSE"
  LICENSE_SHA256 "bdb0a645ea18c60507d0368379b1ac5474b92255fcc2d115e07486a7672ba526"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)

bext_sbom_subcomponent("opencv/opencv" "3rdparty/libtiff"
  NAME "libtiff"
  VERSION "4.7.1"
  UPSTREAM_URL "https://gitlab.com/libtiff/libtiff"
  PURL "pkg:git/gitlab.com/libtiff/libtiff@v4.7.1"
  CPE "cpe:2.3:a:libtiff:libtiff:4.7.1:-:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:libtiff:libtiff:4.7.2:-:*:*:*:*:*:*"
  LICENSE "libtiff"
  LICENSE_FILE "3rdparty/libtiff/LICENSE.md"
  LICENSE_SHA256 "0e27c2382d7b8147972bbb746e04059a1152c8d0fda9d03ef1399d1a433c4ade"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)
