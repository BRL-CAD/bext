bext_package(imath OUTPUT install GROUPS APPLESEED BRLCAD)

bext_sbom_component("imath/Imath"
  UPSTREAM_URL "https://github.com/AcademySoftwareFoundation/Imath"
  VERSION "3.2.3"
  PURL "pkg:github/AcademySoftwareFoundation/Imath@v3.2.3"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "LICENSE.md"
  LICENSE_SHA256 "c20236d3b39fd20eba8e3d1fb3b892a5483df2e7d8d61bf43f165d3fac22f601"
  PURPOSE "LIBRARY"
)
