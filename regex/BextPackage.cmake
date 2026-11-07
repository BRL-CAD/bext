bext_package(regex OUTPUT install GROUPS BRLCAD)

bext_sbom_component("regex/regex"
  UPSTREAM_URL "https://github.com/garyhouston/regex"
  PURL_BASE "pkg:github/BRL-CAD/regex"
)

bext_sbom_component("regex/regex"
  LICENSE "LicenseRef-BRL-CAD-Regex-Aggregate"
  LICENSE_NAME "BRL-CAD regex aggregate license"
  LICENSE_FILE "@/regex/licenses/regex.txt"
  LICENSE_SHA256 "98ba38aebf4fd59458d7cd017bd2ab14cc230d30224128d7b1845e3447055e3e"
  LICENSE_SOURCE_FILE "COPYRIGHT"
  LICENSE_SOURCE_SHA256 "98ba38aebf4fd59458d7cd017bd2ab14cc230d30224128d7b1845e3447055e3e"
  REVIEWED_REVISION "d26a6f727005adf483c84e95b838ac1c7980fea8"
  LICENSE_COMMENT "Contains the non-standard Henry Spencer grant and BSD-3-Clause code."
  PURPOSE "LIBRARY"
)
