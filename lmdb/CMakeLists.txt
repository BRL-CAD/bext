# Decide if we're using lmdb
cad_enable(LMDB "libbu")

bext_enable(LMDB)

# Decision made

if (ENABLE_LMDB)

  git_submodule_init(lmdb libraries/liblmdb/mdb.c)

  TargetDeps(LMDB)

  ExternalProject_Add(LMDB_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/lmdb"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/lmdb.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
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

  TargetInstallDeps(LMDB LMDB_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(READ ${CMAKE_CURRENT_SOURCE_DIR}/lmdb/libraries/liblmdb/COPYRIGHT LMDB_COPYRIGHT)
  file(READ ${CMAKE_CURRENT_SOURCE_DIR}/lmdb/libraries/liblmdb/LICENSE LMDB_LICENSE)
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  file(WRITE ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/lmdb.txt "${LMDB_COPYRIGHT}")
  file(APPEND ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/lmdb.txt "\n")
  file(APPEND ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/lmdb.txt "${LMDB_LICENSE}")

endif (ENABLE_LMDB)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

