bext_package(embree OUTPUT install GROUPS APPLESEED OSPRAY)

bext_sbom_component("embree/embree"
  UPSTREAM_URL "https://github.com/RenderKit/embree"
  VERSION "4.4.1"
  PURL "pkg:github/RenderKit/embree@v4.4.1"
  LICENSE "Apache-2.0"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
)
