bext_package(iwidgets OUTPUT install GROUPS TCL)

bext_sbom_component("iwidgets/iwidgets"
  VERSION "4.1.1"
  REVIEWED_REVISION "ce8f624329a32c042c7da110166d03a6f5ad03c3"
  UPSTREAM_URL "https://core.tcl-lang.org/iwidgets"
  PURL_BASE "pkg:github/BRL-CAD/iwidgets"
  LICENSE "TCL"
  LICENSE_FILE "license.terms"
  LICENSE_SHA256 "9967a599e4a8e7754d883c223dc459fbfe3ba642bb9224fa3359cbcfdb5f4a2d"
)
