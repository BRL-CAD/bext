# Decide if we need to build the portable m4 implementation.
bext_enable_all_default(M4 m4)

if (NOT ENABLE_M4)
  find_program(M4_EXECUTABLE m4)
  if (NOT M4_EXECUTABLE AND NOT DEFINED ENABLE_M4)
    set(ENABLE_M4 ON CACHE BOOL "Enable portable m4 build")
  endif ()
endif ()
set(ENABLE_M4 "${ENABLE_M4}" CACHE BOOL "Enable portable m4 build")

if (ENABLE_M4)
  git_submodule_init(m4 LICENSE
    PATCH_FILES "${CMAKE_CURRENT_SOURCE_DIR}/m4_windows.patch"
    PATCH_COMMAND_VAR M4_PATCH_COMMAND)

  RegisterDeps(M4)

  if (WIN32)
    set(M4_FLEX_NAME win_flex.exe)
    set(M4_BISON_NAME win_bison.exe)
  else ()
    set(M4_FLEX_NAME flex)
    set(M4_BISON_NAME bison)
  endif ()

  if (FLEX_TARGET)
    set(M4_FLEX_EXECUTABLE
      "${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/${M4_FLEX_NAME}")
  else ()
    set(M4_FLEX_EXECUTABLE "${FLEX_EXECUTABLE}")
  endif ()
  if (BISON_TARGET)
    set(M4_BISON_EXECUTABLE
      "${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/${M4_BISON_NAME}")
  else ()
    set(M4_BISON_EXECUTABLE "${BISON_EXECUTABLE}")
  endif ()

  ExternalProject_Add(M4_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/m4"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${M4_PATCH_COMMAND}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DOM4_PROGRAM_NAME=m4
    -DOM4_GNU_COMPAT_DEFAULT=ON
    -DBUILD_TESTING=OFF
    -DFLEX_EXECUTABLE=${M4_FLEX_EXECUTABLE}
    -DBISON_EXECUTABLE=${M4_BISON_EXECUTABLE}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
  )

  TargetInstallDeps(M4 M4_DEPENDS)

  set(M4_EXECUTABLE
    "${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/m4${CMAKE_EXECUTABLE_SUFFIX}"
    CACHE FILEPATH "m4 macro processor" FORCE)
elseif (NOT M4_EXECUTABLE)
  message(FATAL_ERROR
    "ISPC requires m4, but no system executable was found and ENABLE_M4 is OFF")
endif ()

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
