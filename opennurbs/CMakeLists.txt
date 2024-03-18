# Unless we have ENABLE_ALL set, base the building of opennurbs on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_OPENNURBS)
  set(ENABLE_OPENNURBS ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_OPENNURBS)

if (NOT ENABLE_OPENNURBS)

  find_package(OPENNURBS)

  # TODO - functionality testing is in order for some of our patches - if
  # we do find a system version, but it fails to work the way we need it to,
  # it's still a no-go

  if (NOT OPENNURBS_FOUND AND NOT DEFINED ENABLE_OPENNURBS)
    set(ENABLE_OPENNURBS "ON" CACHE BOOL "Enable opennurbs build")
  endif (NOT OPENNURBS_FOUND AND NOT DEFINED ENABLE_OPENNURBS)

endif (NOT ENABLE_OPENNURBS)
set(ENABLE_OPENNURBS "${ENABLE_OPENNURBS}" CACHE BOOL "Enable opennurbs build")

if (ENABLE_OPENNURBS)

  git_submodule_init(opennurbs opennurbs.h)

  TargetDeps(OPENNURBS)
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)

  ExternalProject_Add(OPENNURBS_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/opennurbs"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
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
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/opennurbs/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/openNURBS.txt
    COPYONLY
    )

endif (ENABLE_OPENNURBS)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

