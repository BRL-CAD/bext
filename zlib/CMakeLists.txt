# Decide if we're using zlib - it's used by almost everything,
# so if lower level libs than these add it as a dependency
# this list should be updated
cad_enable(ZLIB "libbrep;libicv;libgcv")

bext_enable(ZLIB)

# Decision made

if (ENABLE_ZLIB)

  git_submodule_init(zlib zlib.h)

  RegisterDeps(ZLIB)

  set(Z_PREFIX_STR "brl_")
  mark_as_advanced(Z_PREFIX_STR)

  ExternalProject_Add(ZLIB_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/zlib"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/zlib_cmake.patch
    COMMAND ${CMAKE_COMMAND};-E;rename;<SOURCE_DIR>/zlib.h;<SOURCE_DIR>/zlib.h.in
    COMMAND ${CMAKE_COMMAND};-E;rename;<SOURCE_DIR>/zconf.h;<SOURCE_DIR>/zconf.h.in
    COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/zlib_rc.patch
    COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/zlib_prefix.patch
    CMAKE_ARGS
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    ${BUILD_TYPE_SPECIFIER}
    -DZ_PREFIX_STR=${Z_PREFIX_STR}
    -DZLIB_BUILD_EXAMPLES=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
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

  TargetInstallDeps(ZLIB ZLIB_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/zlib/LICENSE
    ${DOC_LICENSE_DIR}/zlib.txt
    COPYONLY
    )

endif (ENABLE_ZLIB)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

