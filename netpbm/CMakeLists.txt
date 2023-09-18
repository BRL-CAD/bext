# Unless we have ENABLE_ALL set, based the building of netpbm on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_NETPBM)
  set(ENABLE_NETPBM ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_NETPBM)

if (NOT ENABLE_NETPBM)

  find_package(NETPBM)

  if (NOT NETPBM_FOUND AND NOT DEFINED ENABLE_NETPBM)
    set(ENABLE_NETPBM "ON" CACHE BOOL "Enable netpbm build")
  endif (NOT NETPBM_FOUND AND NOT DEFINED ENABLE_NETPBM)

endif (NOT ENABLE_NETPBM)
set(ENABLE_NETPBM "${ENABLE_NETPBM}" CACHE BOOL "Enable netpbm build")

if (ENABLE_NETPBM)

  git_submodule_init(netpbm CMakeLists.txt)

  ExternalProject_Add(NETPBM_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/netpbm"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(NETPBM_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/netpbm.txt
    COPYONLY
    )

endif (ENABLE_NETPBM)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

