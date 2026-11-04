# Decide if we're using PROJ (needed by GDAL, which is used by gcv)
cad_enable(PROJ "libgcv")

bext_enable(PROJ)

# Decision made

if (ENABLE_PROJ)

  set(PROJ_PATCH_FILES "${CMAKE_CURRENT_SOURCE_DIR}/proj.patch")
  git_submodule_init(PROJ CMakeLists.txt
    PATCH_FILES ${PROJ_PATCH_FILES}
    PATCH_COMMAND_VAR PROJ_PATCH_COMMAND)

  RegisterDeps(PROJ)

  # An empty EXE_SQLITE3 cache entry prevents PROJ's find_program call from
  # searching for a system shell.  Always pass the selected executable.
  if (SQLITE3_TARGET)
    set(PROJ_SQLITE3_EXECUTABLE
      "${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/sqlite3${CMAKE_EXECUTABLE_SUFFIX}")
  else ()
    find_program(PROJ_SQLITE3_EXECUTABLE NAMES sqlite3 sqlite REQUIRED)
  endif ()

  ExternalProject_Add(PROJ_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/PROJ"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PROJ_PATCH_COMMAND}
    COMMAND ${CMAKE_COMMAND};-E;copy;${CMAKE_CURRENT_SOURCE_DIR}/../CMake/FindSQLite3.cmake;<SOURCE_DIR>/cmake/FindSQLite3.cmake
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
    -DPROJ_LIB_DIR=${CMAKE_BUNDLE_INSTALL_PREFIX}/${DATA_DIR}/proj
    -DSQLite3_ROOT=$<$<BOOL:${SQLITE3_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DEXE_SQLITE3=${PROJ_SQLITE3_EXECUTABLE}
    -DBUILD_TESTING=OFF
    -DBUILD_APPS=OFF
    -DENABLE_TIFF=OFF
    -DENABLE_CURL=OFF
    -DBUILD_PROJSYNC=OFF
    DEPENDS ${PROJ_DEPS}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(PROJ PROJ_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/PROJ/COPYING
    ${DOC_LICENSE_DIR}/proj.txt
    COPYONLY
    )

endif (ENABLE_PROJ)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

