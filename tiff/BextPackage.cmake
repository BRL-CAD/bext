bext_package(tiff OUTPUT install GROUPS APPLESEED GDAL)

bext_sbom_component("tiff/libtiff" UPSTREAM_URL "https://gitlab.com/libtiff/libtiff")

bext_sbom_component("tiff/libtiff"
  VERSION "4.7.2"
  PURL "pkg:git/gitlab.com/libtiff/libtiff@v4.7.2"
  CPE "cpe:2.3:a:libtiff:libtiff:4.7.2:-:*:*:*:*:*:*"
  CPE_STATUS "NVD_EXACT"
)

bext_sbom_component("tiff/libtiff"
  LICENSE "libtiff"
  LICENSE_FILE "LICENSE.md"
  LICENSE_SHA256 "0e27c2382d7b8147972bbb746e04059a1152c8d0fda9d03ef1399d1a433c4ade"
)
