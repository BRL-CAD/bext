# Unless we have ENABLE_ALL set, base the building of manifold on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_MANIFOLD)
  set(ENABLE_MANIFOLD ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_MANIFOLD)

if (NOT ENABLE_MANIFOLD)

  find_package(MANIFOLD)

  # TODO - functionality testing is in order for some of our patches - if
  # we do find a system version, but it fails to work the way we need it to,
  # it's still a no-go

  if (NOT MANIFOLD_FOUND AND NOT DEFINED ENABLE_MANIFOLD)
    set(ENABLE_MANIFOLD "ON" CACHE BOOL "Enable manifold build")
  endif (NOT MANIFOLD_FOUND AND NOT DEFINED ENABLE_MANIFOLD)

endif (NOT ENABLE_MANIFOLD)
set(ENABLE_MANIFOLD "${ENABLE_MANIFOLD}" CACHE BOOL "Enable manifold build")

if (ENABLE_MANIFOLD)

  git_submodule_init(manifold include/manifold/manifold.h)

  TargetDeps(MANIFOLD)

  ExternalProject_Add(MANIFOLD_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/manifold"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/manifold.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DASSETIMPORT_ROOT=$<$<BOOL:${ASSETIMPORT_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DMANIFOLD_EXPORT=ON
    -DGLM_BUILD_LIBRARY=OFF
    -DGLM_BUILD_INSTALL=ON
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(MANIFOLD MANIFOLD_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/manifold/LICENSES.txt
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/manifold.txt
    COPYONLY
    )

endif (ENABLE_MANIFOLD)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

