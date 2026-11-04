# Decide if we're using openNURBS
cad_enable(OPENNURBS "libbrep")

bext_enable(OPENNURBS)

# Decision made, start processing if we are enabled

if (ENABLE_OPENNURBS)

  set(OPENNURBS_PATCH_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_android_uuid.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_brep_cpp.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_brep_h.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_cmake.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_compress.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_defines_h.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_defines_cpp.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_example_brep.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_example_gl.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_file_utilities.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_font.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_memory.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_locale.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_object_history.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_optimize.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_polyline.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_precompiledheader.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_string_format.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_string_scan.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_system.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_system_runtime.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_uuid.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_version_number.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_x.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_zlib.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_post_effects.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs_3dm_attributes.patch")
  git_submodule_init(opennurbs opennurbs.h
    PATCH_FILES ${OPENNURBS_PATCH_FILES}
    PATCH_COMMAND_VAR OPENNURBS_PATCH_COMMAND)

  RegisterDeps(OPENNURBS)
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)

  ExternalProject_Add(OPENNURBS_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/addfiles/opennurbs_x.cpp <SOURCE_DIR>
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/addfiles/opennurbs_x.h <SOURCE_DIR>
    COMMAND ${OPENNURBS_PATCH_COMMAND}
    COMMAND ${CMAKE_COMMAND};-E;copy;${PROJECT_SOURCE_DIR}/CMake/FindZLIB.cmake;<SOURCE_DIR>/CMake/FindZLIB.cmake
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(OPENNURBS OPENNURBS_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/opennurbs/LICENSE
    ${DOC_LICENSE_DIR}/openNURBS.txt
    COPYONLY
    )

endif (ENABLE_OPENNURBS)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

