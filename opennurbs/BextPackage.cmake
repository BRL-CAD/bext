bext_package(opennurbs OUTPUT install GROUPS BRLCAD
  LEGAL_NAMES
    openNURBS
)

bext_sbom_component("opennurbs/opennurbs"
  UPSTREAM_URL "https://github.com/mcneel/opennurbs"
  VERSION "8.34.26223.11001"
  PURL "pkg:github/mcneel/opennurbs@v8.34.26223.11001"
  LICENSE "LicenseRef-openNURBS-Aggregate"
  LICENSE_NAME "openNURBS aggregate license"
  LICENSE_FILE "@/opennurbs/licenses/opennurbs.txt"
  LICENSE_SHA256 "de437cd429817f50999710543b9d3e743b17b35b4c96842393b9d39f7bb9b3bd"
  LICENSE_SOURCE_FILE "./LICENSE"
  LICENSE_SOURCE_SHA256 "de437cd429817f50999710543b9d3e743b17b35b4c96842393b9d39f7bb9b3bd"
  REVIEWED_REVISION "23fc677ba06e49212296ca75fab7fb6c2851b4ce"
  LICENSE_COMMENT "Preserves the openNURBS terms and the bundled zlib notice verbatim."
  PURPOSE "LIBRARY"
)
