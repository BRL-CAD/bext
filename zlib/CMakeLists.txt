# Unless we have ENABLE_ALL set, base the building of zlib on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_ZLIB)
  set(ENABLE_ZLIB ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_ZLIB)

if (NOT ENABLE_ZLIB)

  find_package(ZLIB)

  if (NOT ZLIB_FOUND AND NOT DEFINED ENABLE_ZLIB)
    set(ENABLE_ZLIB "ON" CACHE BOOL "Enable zlib build")
  endif (NOT ZLIB_FOUND AND NOT DEFINED ENABLE_ZLIB)

endif (NOT ENABLE_ZLIB)
set(ENABLE_ZLIB "${ENABLE_ZLIB}" CACHE BOOL "Enable zlib build")

if (ENABLE_ZLIB)

  git_submodule_init(zlib zlib.h)

  set(Z_PREFIX_STR "brl_")
  mark_as_advanced(Z_PREFIX_STR)

  ExternalProject_Add(ZLIB_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/zlib"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/zlib.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DZ_PREFIX_STR=${Z_PREFIX_STR}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(ZLIB_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/zlib/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/zlib.txt
    COPYONLY
    )

endif (ENABLE_ZLIB)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

