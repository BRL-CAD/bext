# Unless we have ENABLE_ALL set, based the building of LLVM on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_LLVM)
  set(ENABLE_LLVM ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_LLVM)

if (NOT ENABLE_LLVM)

  find_package(LLVM)

  if (NOT LLVM_FOUND AND NOT DEFINED ENABLE_LLVM)
    set(ENABLE_LLVM "ON" CACHE BOOL "Enable LLVM build")
  endif (NOT LLVM_FOUND AND NOT DEFINED ENABLE_LLVM)

endif (NOT ENABLE_LLVM)
set(ENABLE_LLVM "${ENABLE_LLVM}" CACHE BOOL "Enable LLVM build")

if (ENABLE_LLVM)

  git_submodule_init(llvm-project llvm/CMakeLists.txt)

  # LLVM doesn't accept an empty CMAKE_BUILD_TYPE
  get_property(isMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  set(BUILD_TYPE_SPECIFIER)
  if (NOT isMultiConfig)
    if (NOT CMAKE_BUILD_TYPE)
      set(BUILD_TYPE_SPECIFIER "-DCMAKE_BUILD_TYPE=Release")
    else (NOT CMAKE_BUILD_TYPE)
      set(BUILD_TYPE_SPECIFIER "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    endif (NOT CMAKE_BUILD_TYPE)
  endif (NOT isMultiConfig)

  TargetDeps(LLVM)

  # We may need one or more patches, depending on settings.  ExternalProject_Add
  # expects the first command to be "PATCH_COMMAND", with subsequent patch commands
  # starting with COMMAND.  Use a variable initialized to PATCH_COMMAND, with each
  # activation of a patch flipping the variable to COMMAND for subsequent uses.
  set(PATCH_CMD "PATCH_COMMAND")
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
    set(Z_BRL_PATCH_CMD "${PATCH_CMD};${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/llvm_z_brl.patch")
    set(PATCH_CMD "COMMAND")
  endif (TARGET ZLIB_BLD)
  set(IS_MSVC 0)
  if (MSVC)
    set(IS_MSVC 1)
    set(Z_NO_AST_INTRO_PATCH_CMD "${PATCH_CMD};${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/llvm_no_ast_introspection.patch")
    set(PATCH_CMD "COMMAND")
  endif (MSVC)

  ExternalProject_Add(LLVM_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/llvm-project"
    SOURCE_SUBDIR llvm
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    ${Z_BRL_PATCH_CMD}
    ${Z_NO_AST_INTRO_PATCH_CMD}
    CMAKE_ARGS
    -C ${CMAKE_CURRENT_SOURCE_DIR}/llvm_targets.cmake
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DLLVM_BUILD_DOCS=OFF
    -DLLVM_BUILD_EXAMPLES=OFF
    -DLLVM_ENABLE_LIBEDIT=OFF
    -DLLVM_ENABLE_PROJECTS=clang
    -DLLVM_ENABLE_ZSTD=OFF
    -DLLVM_PARALLEL_LINK_JOBS=1 # llvm/clang linking is memory hungry
    -DLLVM_OPTIMIZED_TABLEGEN=ON
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    # we don't need LLVM itself to be debuggable.  Prevents .pdb and .ilk bloat.
    $<AND:${IS_MSVC},$<CONFIG:Debug>:-DCMAKE_CXX_FLAGS_DEBUG=/DEBUG:NONE>
    $<AND:${IS_MSVC},$<CONFIG:Debug>:-DCMAKE_EXE_LINKER_FLAGS_DEBUG=/DEBUG:NONE /INCREMENTAL:NO>
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(LLVM LLVM_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/llvm-project/llvm/LICENSE.TXT
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/LLVM.txt
    COPYONLY
    )

endif (ENABLE_LLVM)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

