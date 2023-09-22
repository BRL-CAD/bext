# Unless we have ENABLE_ALL set, based the building of lz4 on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_LZ4)
  set(ENABLE_LZ4 ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_LZ4)

if (NOT ENABLE_LZ4)

  find_package(LZ4)

  if (NOT LZ4_FOUND AND NOT DEFINED ENABLE_LZ4)
    set(ENABLE_LZ4 "ON" CACHE BOOL "Enable lz4 build")
  endif (NOT LZ4_FOUND AND NOT DEFINED ENABLE_LZ4)

endif (NOT ENABLE_LZ4)
set(ENABLE_LZ4 "${ENABLE_LZ4}" CACHE BOOL "Enable lz4 build")

if (ENABLE_LZ4)

  git_submodule_init(lz4 CMakeLists.txt)

  ExternalProject_Add(LZ4_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/lz4"
    SOURCE_SUBDIR build/cmake
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DLZ4_BUILD_CLI=OFF
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
    ExternalProject_Add_StepDependencies(LZ4_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/lz4/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/lz4.txt
    COPYONLY
    )

endif (ENABLE_LZ4)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

