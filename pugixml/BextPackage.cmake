bext_package(pugixml OUTPUT install GROUPS BRLCAD APPLESEED)

bext_sbom_component("pugixml/pugixml"
  UPSTREAM_URL "https://github.com/zeux/pugixml"
  VERSION "1.16"
  PURL "pkg:github/zeux/pugixml@v1.16"
  LICENSE "MIT"
  LICENSE_FILE "LICENSE.md"
  LICENSE_SHA256 "90974fbb120e966b452654eaae3ba6ee55f3647db3b28918a7649733ee99da97"
)
