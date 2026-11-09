bext_package(lmdb OUTPUT install GROUPS BRLCAD)

bext_sbom_component("lmdb/lmdb"
  UPSTREAM_URL "https://github.com/LMDB/lmdb"
  LICENSE "OLDAP-2.8"
  LICENSE_FILE "libraries/liblmdb/LICENSE"
  LICENSE_SHA256 "310fe25c858a9515fc8c8d7d1f24a67c9496f84a91e0a0e41ea9975b1371e569"
  VERSION "1.0.1"
  PURL "pkg:github/LMDB/lmdb@LMDB_1.0.1"
)
