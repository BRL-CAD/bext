function(bext_test_tiff_sbom sbom)
  bext_test_sbom_package(package "${sbom}" SPDXRef-Package-tiff-libtiff)
  bext_test_sbom_reference("${package}" cpe23Type "cpe:2.3:a:libtiff:libtiff:4.7.2:-:*:*:*:*:*:*")
endfunction()
