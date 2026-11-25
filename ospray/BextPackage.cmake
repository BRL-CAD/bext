bext_package(ospray OUTPUT install GROUPS OSPRAY)

bext_sbom_component("ospray/ospray"
  UPSTREAM_URL "https://github.com/RenderKit/ospray"
  VERSION "3.2.0"
  PURL "pkg:github/RenderKit/ospray@v3.2.0"
  LICENSE "Apache-2.0"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "5df2a0d87d6c562f0ea11c688ac52532aa28d744cabc7994ff0537f64b3b3320"
)
