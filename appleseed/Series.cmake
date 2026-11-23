set(APPLESEED_BOOTSTRAP_PATCH_FILES
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_dependency_modules.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_native_build_targets.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_library_api_compatibility.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_shader_api_compatibility.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_support_files.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_platform_and_bundled_libraries.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_core_and_developer_fixes.patch"
  )

set(APPLESEED_BOOST_PATCH_FILES
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_optional_and_unused_wave.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_lru_cache_index.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_shader_area_index.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_filesystem.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_atomics.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_threads.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_chrono.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_denoiser_workers.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_regex_and_build.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_shader_resources.patch"
  )

set(APPLESEED_ART_PATCH_FILES
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_procedural_surfaces.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_osl_input_contracts.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_bump_and_texture_nodes.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_struetype.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_ideal_glass.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_closure_mixtures.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_coat_closures.patch"
  "${CMAKE_CURRENT_LIST_DIR}/appleseed_panorama_and_image_helpers.patch"
  )

set(APPLESEED_PATCH_STAGE "ART" CACHE STRING
  "Appleseed patch stage: CORE removes Boost; ART adds renderer integration features")
set_property(CACHE APPLESEED_PATCH_STAGE PROPERTY STRINGS CORE ART)

set(APPLESEED_PATCH_FILES
  ${APPLESEED_BOOTSTRAP_PATCH_FILES}
  ${APPLESEED_BOOST_PATCH_FILES}
  )
if(APPLESEED_PATCH_STAGE STREQUAL "ART")
  list(APPEND APPLESEED_PATCH_FILES ${APPLESEED_ART_PATCH_FILES})
elseif(NOT APPLESEED_PATCH_STAGE STREQUAL "CORE")
  message(FATAL_ERROR "APPLESEED_PATCH_STAGE must be CORE or ART")
endif()
