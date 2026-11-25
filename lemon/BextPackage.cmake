bext_package(lemon OUTPUT noinstall GROUPS BRLCAD)

bext_sbom_component("lemon/lemon"
  UPSTREAM_URL "https://sqlite.org/src/dir?ci=trunk&name=tool"
  PURL_BASE "pkg:github/BRL-CAD/lemon"
  LICENSE "LicenseRef-Lemon-Public-Domain"
  LICENSE_NAME "Lemon public-domain dedication"
  LICENSE_FILE "@/lemon/licenses/lemon.txt"
  LICENSE_SHA256 "3df1e484c4bfbcb805c5cfa305df38c529ca675be5e81951cb78eff61d2c5152"
  REVIEWED_REVISION "b0e459f6feb0ee5ed4167192bdbbb0270eaf0ecd"
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)
