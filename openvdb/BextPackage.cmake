bext_package(openvdb OUTPUT install GROUPS BRLCAD)

bext_sbom_component("openvdb/openvdb"
  VERSION "13.0.1"
  REVIEWED_REVISION "c81d904dede13fb698f9e2e40a5189781ca92a35"
  UPSTREAM_URL "https://github.com/AcademySoftwareFoundation/openvdb"
  PURL_BASE "pkg:github/AcademySoftwareFoundation/openvdb"
)

bext_sbom_component("openvdb/openvdb"
  LICENSE "Apache-2.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "a6cba85bc92e0cff7a450b1d873c0eaa2e9fc96bf472df0247a26bec77bf3ff9"
)
