# Unless we have ENABLE_ALL set, based the building of fmt on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_FMT)
  set(ENABLE_FMT ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_FMT)

if (NOT ENABLE_FMT)

  find_package(FMT)

  if (NOT FMT_FOUND AND NOT DEFINED ENABLE_FMT)
    set(ENABLE_FMT "ON" CACHE BOOL "Enable fmt build")
  endif (NOT FMT_FOUND AND NOT DEFINED ENABLE_FMT)

endif (NOT ENABLE_FMT)
set(ENABLE_FMT "${ENABLE_FMT}" CACHE BOOL "Enable fmt build")

if (ENABLE_FMT)

  git_submodule_init(fmt CMakeLists.txt)

  set(FMT_DEPENDS PATCH)
  TargetVars(FMT_DEPENDS)

  ExternalProject_Add(FMT_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/fmt"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    -DFMT_DOC=OFF
    -DFMT_TEST=OFF
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

  TargetInstallDeps(FMT FMT_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/fmt/LICENSE.rst
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/fmt.txt
    COPYONLY
    )

endif (ENABLE_FMT)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

