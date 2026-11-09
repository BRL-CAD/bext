bext_package(opencolorio OUTPUT install GROUPS APPLESEED)

bext_sbom_component("opencolorio/OpenColorIO"
  UPSTREAM_URL "https://github.com/AcademySoftwareFoundation/OpenColorIO"
  VERSION "2.3.2"
  PURL "pkg:github/AcademySoftwareFoundation/OpenColorIO@v2.3.2"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "82a40c52065ee968aa62015735e84378ac11425db7a233e6a2dcd2c83fc24276"
)
