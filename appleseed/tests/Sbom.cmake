function(bext_test_appleseed_sbom sbom)
  set(appleseed_cache "${BEXT_SBOM_OUTPUT}.appleseed-cache")
  file(WRITE "${appleseed_cache}" [=[
WITH_PYTHON2_BINDINGS:BOOL=OFF
WITH_PYTHON3_BINDINGS:BOOL=OFF
]=])
  include("${BEXT_SOURCE_DIR}/appleseed/SbomSelection.cmake")
  bext_appleseed_selected_packages(appleseed_selected_packages "${appleseed_cache}")
  file(REMOVE "${appleseed_cache}")
  foreach(required_appleseed_package
      SPDXRef-Package-appleseed-appleseed
      SPDXRef-Package-appleseed-appleseed-src-thirdparty-bcd
      SPDXRef-Package-appleseed-appleseed-src-thirdparty-murmurhash3)
    if(NOT required_appleseed_package IN_LIST appleseed_selected_packages)
      message(FATAL_ERROR "appleseed SBOM selection omitted ${required_appleseed_package}")
    endif()
  endforeach()
  if(SPDXRef-Package-appleseed-appleseed-src-thirdparty-glad IN_LIST appleseed_selected_packages)
    message(FATAL_ERROR "appleseed SBOM selection retained build-only GLAD")
  endif()
  bext_test_sbom_package(package "${sbom}" SPDXRef-Package-appleseed-appleseed)
  string(JSON version GET "${package}" versionInfo)
  bext_test_sbom_reference("${package}" purl "pkg:github/BRL-CAD/appleseed@${version}")
  bext_test_sbom_package(bcd "${sbom}" SPDXRef-Package-appleseed-appleseed-src-thirdparty-bcd)
  bext_test_sbom_reference("${bcd}" purl "pkg:github/BRL-CAD/appleseed@${version}#src/thirdparty/bcd")
endfunction()
