# Unless we have ENABLE_ALL set, based the building of utahrle on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_UTAHRLE)
  set(ENABLE_UTAHRLE ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_UTAHRLE)

if (NOT ENABLE_UTAHRLE)

  find_package(UTAHRLE)

  if (NOT UTAHRLE_FOUND AND NOT DEFINED ENABLE_UTAHRLE)
    set(ENABLE_UTAHRLE "ON" CACHE BOOL "Enable utahrle build")
  endif (NOT UTAHRLE_FOUND AND NOT DEFINED ENABLE_UTAHRLE)

endif (NOT ENABLE_UTAHRLE)
set(ENABLE_UTAHRLE "${ENABLE_UTAHRLE}" CACHE BOOL "Enable utahrle build")

if (ENABLE_UTAHRLE)

  git_submodule_init(utahrle CMakeLists.txt)

  ExternalProject_Add(UTAHRLE_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/utahrle"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
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

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(UTAHRLE_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/utahrle/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/utahrle.txt
    COPYONLY
    )

endif (ENABLE_UTAHRLE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

