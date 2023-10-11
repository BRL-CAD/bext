# Unless we have ENABLE_ALL set, based the building of expat on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_EXPAT)
  set(ENABLE_EXPAT ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_EXPAT)

if (NOT ENABLE_EXPAT)

  find_package(EXPAT)

  if (NOT EXPAT_FOUND AND NOT DEFINED ENABLE_EXPAT)
    set(ENABLE_EXPAT "ON" CACHE BOOL "Enable expat build")
  endif (NOT EXPAT_FOUND AND NOT DEFINED ENABLE_EXPAT)

endif (NOT ENABLE_EXPAT)
set(ENABLE_EXPAT "${ENABLE_EXPAT}" CACHE BOOL "Enable expat build")

if (ENABLE_EXPAT)

  git_submodule_init(libexpat CMakeLists.txt)

  TargetDeps(EXPAT)

  ExternalProject_Add(EXPAT_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/libexpat"
    SOURCE_SUBDIR expat
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

  TargetInstallDeps(EXPAT EXPAT_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/libexpat/COPYING
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/expat.txt
    COPYONLY
    )

endif (ENABLE_EXPAT)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

