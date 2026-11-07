bext_package(itk OUTPUT install GROUPS TCL)

bext_sbom_component("itk/itk"
  VERSION "4.2.7"
  REVIEWED_REVISION "e697407849b01d3498b56fc46e5a423690190954"
  UPSTREAM_URL "https://github.com/tcltk/itk"
  PURL_BASE "pkg:github/tcltk/itk"
)

bext_sbom_component("itk/itk"
  LICENSE "TCL"
  LICENSE_FILE "license.terms"
  LICENSE_SHA256 "30e7313051d2caf5167fdbf26ee445a6b9891db8d0b010928abc8c9e11198787"
)
