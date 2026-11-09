bext_package(flexbison OUTPUT noinstall GROUPS APPLESEED OSPRAY PROVIDERS bison flex)

bext_sbom_component("flexbison/bison"
  UPSTREAM_URL "https://git.savannah.gnu.org/git/bison.git"
  PURL_BASE "pkg:github/BRL-CAD/bison"
  LICENSE "GPL-3.0-or-later"
  LICENSE_FILES "COPYING" "AUTHORS"
  LICENSE_SHA256S
    "3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986"
    "bc5ad04a3bb29a122f64033e12c7108443415634f063d98c5fdca350ae9c8bf9"
  LICENSE_COMMENT "Generated parsers receive the Bison parser exception where applicable. This package describes the build tool itself."
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)

bext_sbom_component("flexbison/flex"
  UPSTREAM_URL "https://github.com/westes/flex"
  VERSION "2.6.4"
  PURL "pkg:github/westes/flex@v2.6.4"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "COPYING"
  LICENSE_SHA256 "97fd685958d93be7f8dab939bb8161dbd6afb0718c63bfc337c24321aea44273"
)

bext_sbom_component("flexbison/winflexbison"
  UPSTREAM_URL "https://github.com/lexxmark/winflexbison"
  VERSION "2.5.25"
  PURL "pkg:github/lexxmark/winflexbison@v2.5.25"
  LICENSE "BSD-3-Clause AND GPL-3.0-or-later AND GFDL-1.3-or-later"
  LICENSE_FILES "flex/src/COPYING" "bison/src/COPYING" "COPYING.DOC" "README.md"
  LICENSE_SHA256S
    "97fd685958d93be7f8dab939bb8161dbd6afb0718c63bfc337c24321aea44273"
    "8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903"
    "6adc7b4f7c74882dbe7564f7b8285ff194d760727ab30036dfe9704039fe32d7"
    "4c36d951368f24436fc490a207e2d1a2f589b4852c66108f565c46d03550b9b2"
  LICENSE_COMMENT "Aggregate covers the bundled Flex sources, Bison sources and build scripts, and documentation."
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)
