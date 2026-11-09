bext_package(proj OUTPUT install GROUPS GDAL)

bext_sbom_component("proj/PROJ"
  UPSTREAM_URL "https://github.com/OSGeo/PROJ"
  VERSION "9.8.1"
  PURL "pkg:github/OSGeo/PROJ@9.8.1"
  LICENSE "MIT"
  LICENSE_FILE "COPYING"
  LICENSE_SHA256 "6a8f30793e877d32e3f88b972f0970a051a3b5a26cd057d3993cb51e21c43319"
)
