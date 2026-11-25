bext_package(pcre2 OUTPUT install GROUPS APPLESEED)

bext_sbom_component("pcre2/pcre2"
  UPSTREAM_URL "https://github.com/PCRE2Project/pcre2"
  VERSION "10.49"
  PURL "pkg:github/PCRE2Project/pcre2@pcre2-10.49"
  LICENSE "BSD-3-Clause WITH PCRE2-exception"
  LICENSE_FILE "LICENCE.md"
  LICENSE_SHA256 "197d8a73ffee0d6b09adba2f9c677b5f5aede24edf89258a68e48248d010d811"
  PURPOSE "LIBRARY"
)
