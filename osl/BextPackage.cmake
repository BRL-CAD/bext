bext_package(osl OUTPUT install GROUPS APPLESEED
  LEGAL_NAMES
    openshadinglanguage
)

bext_sbom_component("osl/OpenShadingLanguage" UPSTREAM_URL "https://github.com/AcademySoftwareFoundation/OpenShadingLanguage")

bext_sbom_component("osl/OpenShadingLanguage" NAME "OpenShadingLanguage")

bext_sbom_component("osl/OpenShadingLanguage"
  VERSION "1.13.10.0"
  PURL "pkg:github/AcademySoftwareFoundation/OpenShadingLanguage@v1.13.10.0"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "LICENSE.md"
  LICENSE_SHA256 "e71783cf069a74ccd462ced30e3b0220c0da3b6524b2acc6af2439150ad32b60"
  PURPOSE "LIBRARY"
)
