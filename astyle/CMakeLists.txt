# Astyle is not bundled with BRL-CAD - it is a source code formatting tool,
# optionally used during compilation to validate our style guidelines.
if (ENABLE_ALL AND NOT DEFINED ENABLE_ASTYLE)
  set(ENABLE_ASTYLE ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_ASTYLE)

if (NOT ENABLE_ASTYLE)

  find_program(ASTYLE_EXECUTABLE astyle)
  mark_as_advanced(ASTYLE_EXECUTABLE)

  if (NOT ASTYLE_EXECUTABLE AND NOT DEFINED ENABLE_ASTYLE)
    set(ENABLE_ASTYLE "ON" CACHE BOOL "Enable astyle build")
  endif (NOT ASTYLE_EXECUTABLE AND NOT DEFINED ENABLE_ASTYLE)

endif (NOT ENABLE_ASTYLE)
set(ENABLE_ASTYLE "${ENABLE_ASTYLE}" CACHE BOOL "Enable astyle build")

if (ENABLE_ASTYLE)

  git_submodule_init(astyle CMakeLists.txt)

  ExternalProject_Add(ASTYLE_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/astyle"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/astyle.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(ASTYLE_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

endif (ENABLE_ASTYLE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

