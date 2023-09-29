# LIEF is a cross platform library which can parse, modify and abstract ELF, PE
# and MachO binary formats.  We use it to define a tool for rpath manipulation.

# We only need LIEF on some platforms - don't worry about trying to build it
# everywhere
if (NOT MSVC AND NOT APPLE)

  if (ENABLE_ALL AND NOT DEFINED ENABLE_LIEF)
    set(ENABLE_LIEF ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_LIEF)

  if (NOT ENABLE_LIEF)

    find_package(LIEF)

    if (NOT LIEF_FOUND AND NOT DEFINED ENABLE_LIEF)
      set(ENABLE_LIEF "ON" CACHE BOOL "Enable LIEF build")
    endif (NOT LIEF_FOUND AND NOT DEFINED ENABLE_LIEF)

  endif (NOT ENABLE_LIEF)

  set(ENABLE_LIEF "${ENABLE_LIEF}" CACHE BOOL "Enable LIEF build")

  if (ENABLE_LIEF)

    git_submodule_init(LIEF CMakeLists.txt)

    set(LIEF_DEPENDS PATCH)
    TargetVars(LIEF_DEPENDS)

    ExternalProject_Add(LIEF_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/LIEF"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/lief.patch
      CMAKE_ARGS
      ${BUILD_TYPE_SPECIFIER}
      -DBIN_DIR=${BIN_DIR}
      -DLIB_DIR=${LIB_DIR}
      -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
      -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
      -DCMAKE_INSTALL_RPATH=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${LIB_DIR}
      -DLIEF_EXAMPLES=OFF
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    TargetInstallDeps(LIEF LIEF_DEPENDS)

  endif (ENABLE_LIEF)
endif (NOT MSVC AND NOT APPLE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

