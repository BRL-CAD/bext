
bext_enable(ISPC)

if (ENABLE_ISPC)

  # You may need to install some packages on Linux:
  # libc6-dev-i386
  # libstdc++-dev-i386-cross
  # gcc-multilib
  # g++-multilib

  git_submodule_init(ispc CMakeLists.txt)

  RegisterDeps(ISPC)
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)
  set(ISPC_PROGRAM_PATH_ARGS)
  if (FLEX_TARGET OR BISON_TARGET)
    list(APPEND ISPC_PROGRAM_PATH_ARGS
      -DCMAKE_PROGRAM_PATH=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}
      )
  endif ()
  if (M4_EXECUTABLE)
    # Normalize to forward slashes.  M4_EXECUTABLE may arrive with native
    # backslashes (e.g. set in CMakePresets as C:\...\m4.exe); passed verbatim
    # through ExternalProject_Add's CMAKE_ARGS those backslashes are consumed as
    # escapes and the ISPC sub-build sees a mangled, non-existent path.
    file(TO_CMAKE_PATH "${M4_EXECUTABLE}" M4_EXECUTABLE_CMAKE)
    list(APPEND ISPC_PROGRAM_PATH_ARGS
      -DM4_EXECUTABLE=${M4_EXECUTABLE_CMAKE}
    )
  endif ()

  # winflexbison installs its binaries as win_flex.exe / win_bison.exe on
  # Windows; the portable names are plain flex / bison elsewhere.
  if (WIN32)
    set(ISPC_FLEX_NAME win_flex.exe)
    set(ISPC_BISON_NAME win_bison.exe)
  else ()
    set(ISPC_FLEX_NAME flex)
    set(ISPC_BISON_NAME bison)
  endif ()

  set(ISPC_FLEXBISON_ARGS)
  if (BISON_TARGET)
    list(APPEND ISPC_FLEXBISON_ARGS
      -DBISON_EXECUTABLE=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/${ISPC_BISON_NAME}
      )
  endif (BISON_TARGET)
  if (FLEX_TARGET)
    list(APPEND ISPC_FLEXBISON_ARGS
      -DFLEX_EXECUTABLE=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/${ISPC_FLEX_NAME}
      )
  endif (FLEX_TARGET)

  # Select the compiler used to build ispc itself.  ispc only forces clang on
  # UNIX (see its CMakeLists.txt); on Windows it happily builds with MSVC, which
  # is in fact the conventional Windows toolchain for ispc.  We therefore only
  # switch to the bundled LLVM clang on non-Windows platforms.  This also avoids
  # a hard incompatibility on Windows, where the bundled LLVM's clang can be too
  # old for a newer MSVC STL (which requires clang builtins the older clang lacks).
  if (LLVM_TARGET AND NOT WIN32)
    set(ISPC_C_COMPILER "${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/clang${CMAKE_EXECUTABLE_SUFFIX}")
    set(ISPC_CXX_COMPILER "${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/clang++${CMAKE_EXECUTABLE_SUFFIX}")
  else ()
    set(ISPC_C_COMPILER "${CMAKE_C_COMPILER}")
    set(ISPC_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
  endif ()

  # ispc links against the bundled LLVM.  Pass the bundled LLVM clang compiler
  # location when we are switching to it (non-Windows); otherwise ispc is built
  # with the native compiler above.
  ExternalProject_Add(ISPC_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/ispc"
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/ispc.patch
    COMMAND ${CMAKE_COMMAND};-E;copy;${PROJECT_SOURCE_DIR}/CMake/FindZLIB.cmake;<SOURCE_DIR>/cmake/FindZLIB.cmake
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    # On Windows ispc links itself with /DEPENDENTLOADFLAG:0x800, which limits
    # the loader to %SystemRoot%\system32 when resolving the exe's imports.  The
    # bundled zlib ships as z_brl.dll in the install tree (not system32), so a
    # dynamically-linked ispc-slim.exe cannot start (exit 0xC0000135,
    # STATUS_DLL_NOT_FOUND) either during the build (when it generates the stdlib
    # bitcode) or once installed.  Link zlib statically so ispc-slim.exe has no
    # non-system DLL dependency and satisfies its own hardening flag.  This is
    # honored by our FindZLIB.cmake, including the find_package(ZLIB) that the
    # bundled LLVM's config re-runs (LLVM is what pulls in the zlib dependency).
    $<$<AND:$<BOOL:${WIN32}>,$<BOOL:${ZLIB_TARGET}>>:-DZLIB_USE_STATIC_LIBS=ON>
    ${ISPC_PROGRAM_PATH_ARGS}
    ${ISPC_FLEXBISON_ARGS}
    -DCurses_ROOT=$<$<BOOL:${NCURSES_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DLLVM_ROOT=$<$<BOOL:${LLVM_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${LLVM_TARGET}>:-DLLVM_CONFIG_EXECUTABLE=${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/llvm-config${CMAKE_EXECUTABLE_SUFFIX}>
    -DISPC_INCLUDE_EXAMPLES=OFF
    -DISPC_INCLUDE_DPCPP_EXAMPLES=OFF
    -DISPC_INCLUDE_TESTS=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${ISPC_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${ISPC_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    # ispc is a build-time codegen tool we never need to debug, and (like LLVM)
    # it statically links the large bundled LLVM.  In a Debug config MSVC links
    # ispc.exe with the default "/debug /INCREMENTAL" and tries to emit a full
    # PDB, which fails with LNK1201 (error writing to program database).  Suppress
    # debug-info generation for the Debug config so ispc links cleanly; the CRT
    # selection (and thus Debug/Release compatibility) is unaffected.  The quotes
    # must wrap the whole -D argument, not just the value -- see llvm/CMakeLists.txt.
    "-DCMAKE_CXX_FLAGS_DEBUG=$<$<CONFIG:Debug>:/DEBUG:NONE>"
    "-DCMAKE_EXE_LINKER_FLAGS_DEBUG=$<$<CONFIG:Debug>:/DEBUG:NONE /INCREMENTAL:NO>"
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(ISPC ISPC_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/ispc/LICENSE.txt
    ${DOC_LICENSE_DIR}/ispc.txt
    COPYONLY
    )

endif (ENABLE_ISPC)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
