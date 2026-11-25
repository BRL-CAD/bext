bext_package(tktable OUTPUT install GROUPS TCL)

bext_sbom_component("tktable/tktable"
  VERSION "2.12.2"
  UPSTREAM_URL "https://github.com/bohagan1/TkTable"
  PURL_BASE "pkg:github/bohagan1/TkTable"
  LICENSE "LicenseRef-Tktable-2.12.2"
  LICENSE_NAME "Tktable 2.12.2 license"
  LICENSE_FILE "@/tktable/licenses/tktable.txt"
  LICENSE_SHA256 "3f8ed9f129ad006a45a662eac5a86d11fe59c2244526ab4dd9291559b6fa3b6b"
  LICENSE_SOURCE_FILE "license.txt"
  LICENSE_SOURCE_SHA256 "3f8ed9f129ad006a45a662eac5a86d11fe59c2244526ab4dd9291559b6fa3b6b"
  REVIEWED_REVISION "5afa983a5359380ad5eaccd02ba42a33641b3de3"
  LICENSE_COMMENT "The grant is Tcl-like but includes an additional bourbon-ware request, so it is preserved as a custom license rather than labeled TCL."
  PURPOSE "LIBRARY"
)
