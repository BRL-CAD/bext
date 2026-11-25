bext_package(onetbb OUTPUT install GROUPS APPLESEED OSPRAY BRLCAD
  LEGAL_NAMES
    oneTBB
)

bext_sbom_component("onetbb/oneTBB"
  UPSTREAM_URL "https://github.com/uxlfoundation/oneTBB"
  NAME "oneTBB"
  VERSION "2023.1.0"
  PURL "pkg:github/uxlfoundation/oneTBB@v2023.1.0"
  LICENSE "Apache-2.0"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
)
