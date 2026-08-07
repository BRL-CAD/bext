# We only need plief's RPATH manipulation on some
# platforms - don't worry about trying to build it
# everywhere
if (NOT MSVC AND NOT APPLE)

  # Unless we have ENABLE_ALL set, base the building of plief on
  # the system detection results
  bext_enable_all_default(PLIEF plief)

  if (NOT ENABLE_PLIEF)

    find_program(PLIEF_EXECUTABLE plief)
    mark_as_advanced(PLIEF_EXECUTABLE)

    if (NOT PLIEF_EXECUTABLE AND NOT DEFINED ENABLE_PLIEF)
      set(ENABLE_PLIEF "ON" CACHE BOOL "Enable plief build")
    endif (NOT PLIEF_EXECUTABLE AND NOT DEFINED ENABLE_PLIEF)

  endif (NOT ENABLE_PLIEF)
  set(ENABLE_PLIEF "${ENABLE_PLIEF}" CACHE BOOL "Enable plief build")

  if (ENABLE_PLIEF)

    git_submodule_init(plief CMakeLists.txt)

    RegisterDeps(PLIEF)

    # bext: plief bundles cxxopts.hpp which uses uint8_t without including
    # <cstdint>.  GCC 15+ (mingw's default now) tightens header hygiene and
    # errors out at "'uint8_t' does not name a type".  Pre-inject <cstdint>
    # via -include so cxxopts.hpp sees the type without editing the vendored
    # header.  MSVC and Apple never reach this branch (outer NOT MSVC AND NOT
    # APPLE guard); the flag is a no-op on older GCCs / other Clangs so
    # applying it unconditionally within this branch is safe.
    if (WIN32)
      set(PLIEF_BEXT_CXX_FLAGS_INIT "-include cstdint")
    else ()
      set(PLIEF_BEXT_CXX_FLAGS_INIT "")
    endif ()

    ExternalProject_Add(PLIEF_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/plief"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      CMAKE_ARGS
      ${BUILD_TYPE_SPECIFIER}
      -DCMAKE_CXX_FLAGS_INIT=${PLIEF_BEXT_CXX_FLAGS_INIT}
      -DLIEF_ROOT=$<$<BOOL:${LEMON_TARGET}>:${CMAKE_NOBUNDLE_INSTALL_PREFIX}>
      -DBIN_DIR=${BIN_DIR}
      -DLIB_DIR=${LIB_DIR}
      -DDATA_DIR=${DATA_DIR}
      -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
      -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
      -DCMAKE_INSTALL_RPATH=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${LIB_DIR}
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    TargetInstallDeps(PLIEF PLIEF_DEPENDS)

  endif (ENABLE_PLIEF)

endif (NOT MSVC AND NOT APPLE)

# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
