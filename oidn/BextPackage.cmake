bext_package(oidn OUTPUT install GROUPS OSPRAY)

bext_sbom_component("oidn/oidn"
  UPSTREAM_URL "https://github.com/RenderKit/oidn"
  VERSION "2.3.3"
  PURL "pkg:github/RenderKit/oidn@v2.3.3"
  LICENSE "Apache-2.0"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
)

bext_sbom_subcomponent("oidn/oidn" "weights"
  NAME "Intel Open Image Denoise weights"
  UPSTREAM_URL "https://github.com/RenderKit/oidn-weights"
  PURL_BASE "pkg:github/RenderKit/oidn-weights"
  LICENSE "Apache-2.0"
  LICENSE_FILE "weights/LICENSE.txt"
  LICENSE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
  PURPOSE "FILE"
  SCOPE "RUNTIME"
)
