bext_package(netpbm OUTPUT install GROUPS BRLCAD)

bext_sbom_component("netpbm/netpbm"
  UPSTREAM_URL "https://sourceforge.net/projects/netpbm"
  PURL_BASE "pkg:github/BRL-CAD/netpbm"
  LICENSE "LicenseRef-BRL-CAD-Netpbm"
  LICENSE_NAME "BRL-CAD reduced Netpbm license"
  LICENSE_FILE "../LICENSE"
  LICENSE_SHA256 "8299c05cc456fa5bebede11b423743ba8c745a058016a3621d115602e4c7855c"
)
