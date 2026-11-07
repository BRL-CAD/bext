bext_package(fmt OUTPUT install GROUPS APPLESEED)

bext_sbom_component("fmt/fmt" UPSTREAM_URL "https://github.com/fmtlib/fmt")

bext_sbom_component("fmt/fmt"
  VERSION "10.2.1"
  PURL "pkg:github/fmtlib/fmt@10.2.1"
)

bext_sbom_component("fmt/fmt"
  LICENSE "MIT"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "07580f2a3b35709ce703d523f447b242f6dfec7582a8c0df102c7fa2849375f8"
)
