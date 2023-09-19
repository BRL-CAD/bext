# Unless we have ENABLE_ALL set, based the building of xerces-c on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_XERCES_C)
  set(ENABLE_XERCES_C ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_XERCES_C)

if (NOT ENABLE_XERCES_C)

  find_package(XERCES_C)

  if (NOT XERCES_C_FOUND AND NOT DEFINED ENABLE_XERCES_C)
    set(ENABLE_XERCES_C "ON" CACHE BOOL "Enable xerces-c build")
  endif (NOT XERCES_C_FOUND AND NOT DEFINED ENABLE_XERCES_C)

endif (NOT ENABLE_XERCES_C)
set(ENABLE_XERCES_C "${ENABLE_XERCES_C}" CACHE BOOL "Enable xerces-c build")

if (ENABLE_XERCES_C)

  git_submodule_init(xerces-c CMakeLists.txt)

  set(XERCES_C_DEPENDS ICU)
  TargetVars(XERCES_C_DEPENDS)

  ExternalProject_Add(XERCES_C_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/xerces-c"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/xerces-c.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DICU_ROOT=$<$<BOOL:${ICU_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -Dnetwork=OFF
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

  TargetInstallDeps(XERCES_C XERCES_C_DEPENDS)

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(XERCES_C_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/xerces-c/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/xerces-c.txt
    COPYONLY
    )

endif (ENABLE_XERCES_C)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
