bext_package(patch OUTPUT noinstall)

bext_sbom_component("patch/patch"
  UPSTREAM_URL "https://github.com/shannonbooth/patch"
  PURL_BASE "pkg:github/shannonbooth/patch"
)

bext_sbom_component("patch/patch"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "460e39eab45c2037679d6150e5726ed8ba00639111ab07961d0c5fc15cb70d6e"
)
