bext_package(occt OUTPUT install GROUPS BRLCAD)

bext_sbom_component("occt/OCCT"
  NAME "Open CASCADE Technology"
  UPSTREAM_URL "https://github.com/Open-Cascade-SAS/OCCT"
  VERSION "8.0.2"
  PURL "pkg:github/Open-Cascade-SAS/OCCT@V8_0_2"
  LICENSE "LGPL-2.1-only WITH OCCT-exception-1.0"
  LICENSE_FILES "LICENSE_LGPL_21.txt" "OCCT_LGPL_EXCEPTION.txt"
  LICENSE_SHA256S
    "e237fa56668030e928551ddd60f05df5fe957f75eab874bbd017e085ed722e7c"
    "04580a884ea6cea294402649ff7b5cbb167d47462d1340a4ed33e550db10a81b"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)
