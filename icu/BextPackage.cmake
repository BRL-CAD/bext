bext_package(icu OUTPUT install GROUPS APPLESEED)

bext_sbom_component("icu/icu"
  UPSTREAM_URL "https://github.com/unicode-org/icu"
  VERSION "75.1"
  PURL "pkg:github/unicode-org/icu@release-75-1"
  LICENSE "LicenseRef-ICU-75.1-Aggregate"
  LICENSE_NAME "ICU 75.1 aggregate license and third-party notices"
  LICENSE_FILE "@/icu/licenses/icu.txt"
  LICENSE_SHA256 "59f84c28ac3516233b752ee84a601d806a2740f3e25f6e972ac8f6c30b27e64e"
  LICENSE_SOURCE_FILE "./LICENSE"
  LICENSE_SOURCE_SHA256 "3ae033da0bfd60f4609c5c99fe50c0c840685889d3b705d3f527fd7b52032f5c"
  REVIEWED_REVISION "f60c70ad335972045c566bf3165cdad3b8485c63"
  LICENSE_COMMENT "The primary ICU grant is Unicode-3.0. The aggregate also preserves bundled data, build-tool, and third-party notices that cannot be reduced accurately to one standard SPDX expression."
  PURPOSE "LIBRARY"
)
