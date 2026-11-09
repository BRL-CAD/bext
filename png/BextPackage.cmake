bext_package(png OUTPUT install GROUPS APPLESEED BRLCAD TCL)

bext_sbom_component("png/libpng"
  UPSTREAM_URL "https://github.com/pnggroup/libpng"
  NAME "libpng"
  VERSION "1.6.58"
  PURL "pkg:github/pnggroup/libpng@v1.6.58"
  CPE "cpe:2.3:a:libpng:libpng:1.6.58:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_EXACT"
  COPYRIGHT_FILE "@/png/licenses/libpng-copyright.txt"
  COPYRIGHT_SHA256 "68d1f491eaae0a9225a749738a0f65114916fdcce5e22fc06d205cf09d78501b"
  COPYRIGHT_REVIEWED_REVISION "3061454d980de7d53608f594194cfac722721d2a"
  LICENSE "Libpng-2.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "bdb0a645ea18c60507d0368379b1ac5474b92255fcc2d115e07486a7672ba526"
)
