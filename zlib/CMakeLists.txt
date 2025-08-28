# Decide if we're using zlib - it's used by almost everything,
# so if lower level libs than these add it as a dependency
# this list should be updated
cad_enable(ZLIB "libbrep;libicv;libgcv")

bext_enable(ZLIB)

# Decision made

if (ENABLE_ZLIB)

  git_submodule_init(zlib zlib.h)

  RegisterDeps(ZLIB)

  find_program(GIT_EXECUTABLE git REQUIRED)

  set(Z_PREFIX_STR "brl_")
  mark_as_advanced(Z_PREFIX_STR)

  # Define a compact variable for the git repo path
  set(SDIR ${CMAKE_CURRENT_SOURCE_DIR}/zlib)

  ExternalProject_Add(ZLIB_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/zlib"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${GIT_EXECUTABLE};--git-dir;${SDIR}/.git;--work-tree;${SDIR};reset;--hard
    COMMAND ${GIT_EXECUTABLE};--git-dir;${SDIR}/.git;--work-tree;${SDIR};clean;-fdx
    COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/zlib.patch
    COMMAND ${CMAKE_COMMAND} -E remove ${SDIR}/zconf.h
    COMMAND ${CMAKE_COMMAND} -E remove ${SDIR}/zlib.h
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/addfiles/zlib.h.in ${SDIR}
    CMAKE_ARGS
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

