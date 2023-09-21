# Unless we have ENABLE_ALL set, based the building of pystring on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_PYSTRING)
  set(ENABLE_PYSTRING ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_PYSTRING)

if (NOT ENABLE_PYSTRING)

  find_package(PYSTRING)

  if (NOT PYSTRING_FOUND AND NOT DEFINED ENABLE_PYSTRING)
    set(ENABLE_PYSTRING "ON" CACHE BOOL "Enable pystring build")
  endif (NOT PYSTRING_FOUND AND NOT DEFINED ENABLE_PYSTRING)

endif (NOT ENABLE_PYSTRING)
set(ENABLE_PYSTRING "${ENABLE_PYSTRING}" CACHE BOOL "Enable pystring build")

if (ENABLE_PYSTRING)

  git_submodule_init(pystring CMakeLists.txt)

  ExternalProject_Add(PYSTRING_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/pystring"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/pystring.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DZ_PREFIX_STR=${Z_PREFIX_STR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(PYSTRING_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/pystring/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/pystring.txt
    COPYONLY
    )

endif (ENABLE_PYSTRING)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

