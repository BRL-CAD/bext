bext_package(tinygltf OUTPUT install GROUPS BRLCAD)

bext_sbom_component("tinygltf/tinygltf"
  UPSTREAM_URL "https://github.com/syoyo/tinygltf"
  VERSION "3.0.1"
  PURL "pkg:github/syoyo/tinygltf@v3.0.1"
  LICENSE "MIT"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "2ae461f8c8b78ed77c14e9c3b7e353ba277e44cb3dbfb5a6d380f76f2ae081a2"
  LICENSE_COMMENT "This BRL-CAD fork contains the reduced C implementation rather than the older bundled-header source tree."
  PURPOSE "LIBRARY"
)
