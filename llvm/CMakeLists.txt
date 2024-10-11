
bext_enable(LLVM)

if (ENABLE_LLVM)

  git_submodule_init(llvm-project llvm/CMakeLists.txt)

  RegisterDeps(LLVM)

  # We may need one or more patches, depending on settings.  ExternalProject_Add
  # expects the first command to be "PATCH_COMMAND", with subsequent patch commands
  # starting with COMMAND.  Use a variable initialized to PATCH_COMMAND, with each
  # activation of a patch flipping the variable to COMMAND for subsequent uses.
  set(PATCH_CMD "PATCH_COMMAND")
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
    set(Z_BRL_PATCH_CMD "COMMAND;${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/llvm_z_brl.patch")
  endif (TARGET ZLIB_BLD)

  if (WIN32)

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

    ExternalProject_Add(LLVM_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/llvm-project"
      SOURCE_SUBDIR llvm
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE} -E -p1 ${PATCH_OPTIONS} -i "${CMAKE_CURRENT_SOURCE_DIR}/llvm_no_ast_introspection.patch"
      ${Z_BRL_PATCH_CMD}
      CMAKE_ARGS
      -C ${CMAKE_CURRENT_SOURCE_DIR}/llvm_targets.cmake
      -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
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
      -DLLVM_BUILD_LLVM_DYLIB=OFF
      -DLLVM_BUILD_LLVM_C_DYLIB=OFF
      -DBIN_DIR=${BIN_DIR}
      -DLIB_DIR=${LIB_DIR}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
      -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
      -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
      # we don't need LLVM itself to be debuggable.  Prevents .pdb and .ilk bloat.
      -DCMAKE_CXX_FLAGS_DEBUG="$<$<CONFIG:Debug>:/DEBUG:NONE>"
      -DCMAKE_EXE_LINKER_FLAGS_DEBUG="$<$<CONFIG:Debug>:/DEBUG:NONE /INCREMENTAL:NO>"
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )
  else (WIN32)

    if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Release")
      message("NOTE:  Forcing CMAKE_BUILD_TYPE to Release for LLVM compile.  The Debug build configurations of LLVM are EXTREMELY space intensive (to the tune of 50+ gigabytes) and there aren't many scenarios in BRL-CAD usage where we would need to debug into LLVM itself.  If things are that dire the setting in bext/llvm/CMakeLists.txt can be manually edited, but be aware you will need a a few hundred gigabytes of free disk space to handle both the LLVM build/install itself and the copies the BRL-CAD build will make.")
    endif (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Release")

    ExternalProject_Add(LLVM_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/llvm-project"
      SOURCE_SUBDIR llvm
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE} -E -p1 ${PATCH_OPTIONS} -i "${CMAKE_CURRENT_SOURCE_DIR}/llvm_no_ast_introspection.patch"
      ${Z_BRL_PATCH_CMD}
      CMAKE_ARGS
      -C ${CMAKE_CURRENT_SOURCE_DIR}/llvm_targets.cmake
      -DCMAKE_BUILD_TYPE=Release
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
      -DLLVM_BUILD_LLVM_DYLIB=OFF
      -DLLVM_BUILD_LLVM_C_DYLIB=OFF
      -DBIN_DIR=${BIN_DIR}
      -DLIB_DIR=${LIB_DIR}
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
  endif (WIN32)

  TargetInstallDeps(LLVM LLVM_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/llvm-project/llvm/LICENSE.TXT
    ${DOC_LICENSE_DIR}/LLVM.txt
    COPYONLY
    )

endif (ENABLE_LLVM)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

