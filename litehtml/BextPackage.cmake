bext_package(litehtml OUTPUT install GROUPS BRLCAD
  LEGAL_NAMES
    litehtml
    gumbo
)

bext_sbom_component("litehtml/litehtml"
  VERSION "0.10"
  UPSTREAM_URL "https://github.com/litehtml/litehtml"
  PURL "pkg:github/litehtml/litehtml@v0.10"
)

bext_sbom_component("litehtml/litehtml"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "@/litehtml/licenses/litehtml.txt"
  LICENSE_SHA256 "71bd488e77ee821bf38d89e2b8a9c5ebe687553fcae9cefa00a96499792a3e23"
  LICENSE_SOURCE_FILE "./LICENSE"
  LICENSE_SOURCE_SHA256 "71bd488e77ee821bf38d89e2b8a9c5ebe687553fcae9cefa00a96499792a3e23"
  REVIEWED_REVISION "9bc84b8b8d15a4e50f18b327aa30955048b441c2"
  LICENSE_COMMENT "The internally built Gumbo parser is represented as a contained package."
  PURPOSE "LIBRARY"
)

bext_sbom_subcomponent("litehtml/litehtml" "src/gumbo"
  NAME "Gumbo Parser"
  VERSION "0.12.3"
  UPSTREAM_URL "https://codeberg.org/gumbo-parser/gumbo-parser"
  PURL_BASE "pkg:github/litehtml/litehtml"
  PURL_SUBPATH "src/gumbo"
  LICENSE "Apache-2.0"
  LICENSE_FILE "@/litehtml/licenses/gumbo.txt"
  LICENSE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
  LICENSE_SOURCE_FILE "src/gumbo/LICENSE"
  LICENSE_SOURCE_SHA256 "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
  REVIEWED_REVISION "9bc84b8b8d15a4e50f18b327aa30955048b441c2"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)
