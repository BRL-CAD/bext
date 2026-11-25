function(_bext_assimp_cache_bool output cache_file variable)
  file(STRINGS "${cache_file}" cache_lines REGEX "^${variable}:(BOOL|UNINITIALIZED)=")
  if(cache_lines)
    list(GET cache_lines 0 cache_line)
    string(REGEX REPLACE "^[^=]*=" "" cache_value "${cache_line}")
  else()
    set(cache_value OFF)
  endif()
  if(cache_value)
    set(${output} TRUE PARENT_SCOPE)
  else()
    set(${output} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(bext_assimp_selected_packages output cache_file system_name)
  if(NOT EXISTS "${cache_file}")
    set(${output} "" PARENT_SCOPE)
    return()
  endif()
  set(packages
    SPDXRef-Package-assetimport-assimp
    SPDXRef-Package-assetimport-assimp-contrib-poly2tri
    SPDXRef-Package-assetimport-assimp-contrib-openddlparser
    SPDXRef-Package-assetimport-assimp-contrib-rapidjson
    SPDXRef-Package-assetimport-assimp-contrib-utf8cpp
    SPDXRef-Package-assetimport-assimp-contrib-clipper
    SPDXRef-Package-assetimport-assimp-contrib-earcut-hpp
    SPDXRef-Package-assetimport-assimp-contrib-stb
  )
  _bext_assimp_cache_bool(has_minizip "${cache_file}" ASSIMP_BUILD_MINIZIP)
  if(has_minizip)
    list(APPEND packages SPDXRef-Package-assetimport-assimp-contrib-unzip)
  endif()
  _bext_assimp_cache_bool(has_3mf "${cache_file}" ASSIMP_BUILD_3MF_EXPORTER)
  if(has_3mf)
    list(APPEND packages SPDXRef-Package-assetimport-assimp-contrib-zip)
  endif()
  _bext_assimp_cache_bool(has_gltf "${cache_file}" ASSIMP_BUILD_GLTF_IMPORTER)
  _bext_assimp_cache_bool(has_rt "${cache_file}" RT_FOUND)
  if(has_gltf AND (system_name STREQUAL "Windows" OR has_rt))
    list(APPEND packages SPDXRef-Package-assetimport-assimp-contrib-Open3DGC)
  endif()
  list(REMOVE_DUPLICATES packages)
  list(SORT packages)
  set(${output} "${packages}" PARENT_SCOPE)
endfunction()
