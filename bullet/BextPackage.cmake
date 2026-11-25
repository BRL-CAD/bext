bext_package(bullet OUTPUT install GROUPS BRLCAD)

bext_sbom_component("bullet/bullet3"
  UPSTREAM_URL "https://github.com/bulletphysics/bullet3"
  PURL_BASE "pkg:github/bulletphysics/bullet3"
  LICENSE "Zlib"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "885cd516a8420acb7c3e0b1a7119913b686495001ae564e3229740460e8cff59"
  LICENSE_COMMENT "bext disables Extras, demos, tests, ENet, CLSocket, and Bullet3. This declaration covers the installed Bullet libraries."
  PURPOSE "LIBRARY"
)
