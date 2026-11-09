bext_package(tk OUTPUT install GROUPS TCL)

bext_sbom_component("tk/tk"
  UPSTREAM_URL "https://github.com/tcltk/tk"
  VERSION "8.6.18"
  PURL "pkg:github/tcltk/tk@core-8-6-18"
  LICENSE "TCL"
  LICENSE_FILE "license.terms"
  LICENSE_SHA256 "2cde822b93ca16ae535c954b7dfe658b4ad10df2a193628d1b358f1765e8b198"
  PURPOSE "LIBRARY"
)
