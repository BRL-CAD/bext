bext_package(re2c OUTPUT noinstall GROUPS BRLCAD)

bext_sbom_component("re2c/re2c" UPSTREAM_URL "https://github.com/skvadrik/re2c")

bext_sbom_component("re2c/re2c"
  VERSION "4.6"
  PURL "pkg:github/skvadrik/re2c@4.6"
)

bext_sbom_component("re2c/re2c"
  LICENSE "LicenseRef-re2c-Public-Domain"
  LICENSE_NAME "re2c public-domain dedication"
  LICENSE_FILE "@/re2c/licenses/re2c.txt"
  LICENSE_SHA256 "a198b90b930ac528161193ec9f5537ecb5a9f569ec99c6130c95a12190936b36"
  LICENSE_SOURCE_FILE "./LICENSE"
  LICENSE_SOURCE_SHA256 "a198b90b930ac528161193ec9f5537ecb5a9f569ec99c6130c95a12190936b36"
  REVIEWED_REVISION "e485c5d572ab8a9f895b2a3c98e5239bf59254c8"
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)
