# LIEF is a cross platform library which can parse, modify and abstract ELF, PE
# and MachO binary formats.  We use it to define a tool for rpath manipulation.

# Untested on Windows
if (NOT MSVC)

  bext_enable(LIEF)

  if (ENABLE_LIEF)

    git_submodule_init(LIEF CMakeLists.txt)

    RegisterDeps(LIEF)

    ExternalProject_Add(LIEF_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/LIEF"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/lief.patch
      COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/filestream.patch
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
      -DLIEF_ART=OFF
      -DLIEF_ASAN=OFF
      -DLIEF_C_API=OFF
      -DLIEF_DEX=OFF
      -DLIEF_DOC=OFF
      -DLIEF_ENABLE_JSON=OFF
      -DLIEF_EXAMPLES=OFF
      -DLIEF_FUZZING=OFF
      -DLIEF_LSAN=OFF
      -DLIEF_MACHO=OFF
      -DLIEF_OAT=OFF
      -DLIEF_PE=OFF
      -DLIEF_PROFILING=OFF
      -DLIEF_PYTHON_API=OFF
      -DLIEF_TESTS=OFF
      -DLIEF_TSAN=OFF
      -DLIEF_USAN=OFF
      -DLIEF_VDEX=OFF
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    TargetInstallDeps(LIEF LIEF_DEPENDS)

  endif (ENABLE_LIEF)
endif (NOT MSVC)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

