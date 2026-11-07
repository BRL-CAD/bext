bext_package(pystring OUTPUT install GROUPS APPLESEED)

bext_sbom_component("pystring/pystring" UPSTREAM_URL "https://github.com/imageworks/pystring")

bext_sbom_component("pystring/pystring"
  VERSION "1.1.4"
  PURL "pkg:github/imageworks/pystring@v1.1.4"
)

bext_sbom_component("pystring/pystring"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "f7f060301402ea0b5c507b865b1a9de037d4d7b24f37422a93b70fe9c7a9b78a"
)
