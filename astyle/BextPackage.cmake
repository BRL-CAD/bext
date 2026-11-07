bext_package(astyle OUTPUT noinstall GROUPS BRLCAD)

bext_sbom_component("astyle/astyle" UPSTREAM_URL "https://gitlab.com/saalen/astyle")

bext_sbom_component("astyle/astyle"
  VERSION "3.6.18"
  PURL "pkg:git/gitlab.com/saalen/astyle@3.6.18"
)

bext_sbom_component("astyle/astyle"
  LICENSE "MIT"
  LICENSE_FILE "AStyle/LICENSE.md"
  LICENSE_SHA256 "2232966052b6cb7eccac3f865549e33ee6040a4b0013d86bce0ca4537cfa5cab"
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)
