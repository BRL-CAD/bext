bext_package(tktable OUTPUT install GROUPS TCL)

bext_sbom_component("tktable/tktable"
  VERSION "2.10"
  UPSTREAM_URL "https://github.com/BRL-CAD/tktable"
  PURL_BASE "pkg:github/BRL-CAD/tktable"
  LICENSE "LicenseRef-Tktable-2.10"
  LICENSE_NAME "Tktable 2.10 license"
  LICENSE_FILE "@/tktable/licenses/tktable.txt"
  LICENSE_SHA256 "3f8ed9f129ad006a45a662eac5a86d11fe59c2244526ab4dd9291559b6fa3b6b"
  LICENSE_SOURCE_FILE "license.txt"
  LICENSE_SOURCE_SHA256 "3f8ed9f129ad006a45a662eac5a86d11fe59c2244526ab4dd9291559b6fa3b6b"
  REVIEWED_REVISION "05e3a95b79c140a5001ba99774209b1ff78026f4"
  LICENSE_COMMENT "The grant is Tcl-like but includes an additional bourbon-ware request, so it is preserved as a custom license rather than labeled TCL."
  PURPOSE "LIBRARY"
)
