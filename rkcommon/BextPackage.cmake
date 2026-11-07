bext_package(rkcommon OUTPUT install GROUPS OSPRAY)

bext_sbom_component("rkcommon/rkcommon" UPSTREAM_URL "https://github.com/RenderKit/rkcommon")

bext_sbom_component("rkcommon/rkcommon"
  VERSION "1.15.2"
  PURL "pkg:github/RenderKit/rkcommon@v1.15.2"
)

bext_sbom_component("rkcommon/rkcommon"
  LICENSE "Apache-2.0"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
)
