function(bext_test_png_sbom sbom)
  bext_test_sbom_package(package "${sbom}" SPDXRef-Package-png-libpng)
  bext_test_sbom_reference("${package}" cpe23Type "cpe:2.3:a:libpng:libpng:1.6.58:*:*:*:*:*:*:*")
endfunction()
