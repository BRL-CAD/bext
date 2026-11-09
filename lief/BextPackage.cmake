bext_package(lief OUTPUT noinstall)

bext_sbom_component("lief/LIEF"
  UPSTREAM_URL "https://github.com/lief-project/LIEF"
  LICENSE "Apache-2.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "998dc6a9d251b4d9d4274d8a7e121fe20c33b1dfd4300bca276e87da23dc582e"
  VERSION "1.0.0"
  PURL "pkg:github/lief-project/LIEF@1.0.0"
)
