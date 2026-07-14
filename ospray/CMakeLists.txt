
bext_enable(OSPRAY)

if (ENABLE_OSPRAY)

  git_submodule_init(ospray CMakeLists.txt)

  RegisterDeps(OSPRAY)

  set(OSPRAY_ISA_ARGS)
  if (APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)")
    list(APPEND OSPRAY_ISA_ARGS
      -DOSPRAY_BUILD_ISA=NEON2X
      )
  endif ()

  ExternalProject_Add(OSPRAY_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/ospray"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    # rkcommon is bundled at 1.15.2 but ospray pins rkcommon EXACT to
    # RKCOMMON_VERSION_REQUIRED (1.14.0).  rkcommon's config uses SameMajorVersion
    # compatibility, so a non-EXACT find accepts 1.15.2 for a 1.14.0 request (and
    # ospray's own installed config already uses find_dependency without EXACT).
    # The patch drops the EXACT keyword from the build-time find_package.
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/ospray.patch
    CMAKE_ARGS
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    ${BUILD_TYPE_SPECIFIER}
    -DEMBREE_ROOT=$<$<BOOL:${EMBREE_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DISPC_ROOT=$<$<BOOL:${ISPC_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${ONETBB_TARGET}>:-DTBB_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DOSPRAY_ENABLE_VOLUMES=OFF
    -DOSPRAY_ENABLE_APPS_BENCHMARK=OFF
    -DOSPRAY_ENABLE_APPS_TESTING=OFF
    -DOSPRAY_ENABLE_APPS_EXAMPLES=OFF
    ${OSPRAY_ISA_ARGS}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
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

  TargetInstallDeps(OSPRAY OSPRAY_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/ospray/LICENSE.txt
    ${DOC_LICENSE_DIR}/ospray.txt
    COPYONLY
    )

endif (ENABLE_OSPRAY)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
