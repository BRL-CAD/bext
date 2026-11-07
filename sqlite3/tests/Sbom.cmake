function(bext_test_sqlite3_sbom sbom)
  bext_test_sbom_package(package "${sbom}" SPDXRef-Package-sqlite3-sqlite3)
  bext_test_sbom_field("${package}" copyrightText NONE)
endfunction()
