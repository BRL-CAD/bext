bext_package(tkhtml OUTPUT install GROUPS TCL)

bext_sbom_component("tkhtml/tkhtml"
  UPSTREAM_URL "https://github.com/BRL-CAD/tkhtml"
  PURL_BASE "pkg:github/BRL-CAD/tkhtml"
)

bext_sbom_component("tkhtml/tkhtml"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "COPYING"
  LICENSE_SHA256 "0d368bb36fb0176bac732a024ac2c1d683aa5f086d2d15595b511d2daefb38cb"
)
