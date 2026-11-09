bext_package(openexr OUTPUT install GROUPS APPLESEED)

bext_sbom_component("openexr/openexr"
  UPSTREAM_URL "https://github.com/AcademySoftwareFoundation/openexr"
  VERSION "3.2.4"
  PURL "pkg:github/AcademySoftwareFoundation/openexr@v3.2.4"
  CPE "cpe:2.3:a:openexr:openexr:3.2.4:-:*:*:*:*:*:*"
  CPE_STATUS "NVD_EXACT"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "LICENSE.md"
  LICENSE_SHA256 "84853c91d4c2e0310741d4773469d98bb93e61029608e0ba0882a3fffdf330bd"
)
