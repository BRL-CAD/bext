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

  # llvm needs zlib - need to do the magic to get it using ours.
  # shows up when trying to compile ispc
  set(LLVM_DEPENDS ZLIB ZSTD)
  TargetVars(LLVM_DEPENDS)
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
    set(Z_BRL_PATCH_CMD "PATCH_COMMAND;${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/llvm_z_brl.patch")
  endif (TARGET ZLIB_BLD)

  ExternalProject_Add(LLVM_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/llvm-project"
    SOURCE_SUBDIR llvm
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    ${Z_BRL_PATCH_CMD}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DZSTD_ROOT=$<$<BOOL:${ZSTD_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DLLVM_BUILD_DOCS=OFF
    -DLLVM_BUILD_EXAMPLES=OFF
    -DLLVM_ENABLE_LIBEDIT=OFF
    -DLLVM_ENABLE_PROJECTS=clang
    -DCLANG_TOOLING_BUILD_AST_INTROSPECTION=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(LLVM LLVM_DEPENDS)

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(LLVM_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

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

