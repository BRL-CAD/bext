# Unless we have ENABLE_ALL set, base the building of strclear on
# the system detection results
bext_enable_all_default(STRCLEAR strclear)

if (NOT ENABLE_STRCLEAR)

  find_program(STRCLEAR_EXECUTABLE strclear)
  mark_as_advanced(STRCLEAR_EXECUTABLE)

  if (NOT STRCLEAR_EXECUTABLE AND NOT DEFINED ENABLE_STRCLEAR)
    set(ENABLE_STRCLEAR "ON" CACHE BOOL "Enable strclear build")
  endif (NOT STRCLEAR_EXECUTABLE AND NOT DEFINED ENABLE_STRCLEAR)

endif (NOT ENABLE_STRCLEAR)
set(ENABLE_STRCLEAR "${ENABLE_STRCLEAR}" CACHE BOOL "Enable strclear build")

if (ENABLE_STRCLEAR)

  git_submodule_init(strclear CMakeLists.txt)

  RegisterDeps(STRCLEAR)

  # strclear is a host-side build utility that scans multi-gigabyte library
  # trees.  It has no ABI relationship with BRL-CAD, and an MSVC Debug build
  # is prohibitively slow because checked iterators run inside its search
  # loops.  Always optimize this helper, including in a Debug bext tree.
  ExternalProject_Add(STRCLEAR_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/strclear"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DDATA_DIR=${DATA_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(STRCLEAR STRCLEAR_DEPENDS)

endif (ENABLE_STRCLEAR)

# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
