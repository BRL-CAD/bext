function(bext_test_assetimport_sbom sbom)
  set(assimp_cache "${BEXT_SBOM_OUTPUT}.assimp-cache")
  file(WRITE "${assimp_cache}" [=[
ASSIMP_BUILD_MINIZIP:BOOL=ON
ASSIMP_BUILD_3MF_EXPORTER:BOOL=ON
ASSIMP_BUILD_GLTF_IMPORTER:BOOL=ON
RT_FOUND:BOOL=OFF
]=])
  include("${BEXT_SOURCE_DIR}/assetimport/SbomSelection.cmake")
  bext_assimp_selected_packages(assimp_selected_packages "${assimp_cache}" Windows)
  file(REMOVE "${assimp_cache}")
  foreach(required_assimp_package
      SPDXRef-Package-assetimport-assimp
      SPDXRef-Package-assetimport-assimp-contrib-poly2tri
      SPDXRef-Package-assetimport-assimp-contrib-openddlparser
      SPDXRef-Package-assetimport-assimp-contrib-rapidjson
      SPDXRef-Package-assetimport-assimp-contrib-utf8cpp
      SPDXRef-Package-assetimport-assimp-contrib-clipper
      SPDXRef-Package-assetimport-assimp-contrib-earcut-hpp
      SPDXRef-Package-assetimport-assimp-contrib-unzip
      SPDXRef-Package-assetimport-assimp-contrib-zip
      SPDXRef-Package-assetimport-assimp-contrib-Open3DGC
      SPDXRef-Package-assetimport-assimp-contrib-stb)
    if(NOT required_assimp_package IN_LIST assimp_selected_packages)
      message(FATAL_ERROR "Assimp SBOM selection omitted ${required_assimp_package}")
    endif()
  endforeach()
endfunction()
