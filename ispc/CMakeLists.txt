
bext_enable(ISPC)

if (ENABLE_ISPC)

  # You may need to install some packages on Linux:
  # libc6-dev-i386
  # libstdc++-dev-i386-cross
  # gcc-multilib
  # g++-multilib

  git_submodule_init(ispc CMakeLists.txt)

  RegisterDeps(ISPC)

  # ispc depends on the clang compiler - its build will switch the compiler if
  # not already using clang.  Need to pass in the bundled LLVM clang compiler
  # location, if we have it.
  ExternalProject_Add(ISPC_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/ispc"
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/ispc.patch
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    $<$<BOOL:${BISON_TARGET}>:-DBISON_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${FLEX_TARGET}>:-DFLEX_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${LLVM_TARGET}>:-DLLVM_CONFIG_EXECUTABLE=${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/llvm-config>
    $<$<BOOL:${LLVM_TARGET}>:-DLLVM_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${NCURSES_TARGET}>:-DCurses_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${ZLIB_TARGET}>:-DZLIB_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DISPC_INCLUDE_EXAMPLES=OFF
    -DISPC_INCLUDE_DPCPP_EXAMPLES=OFF
    -DISPC_INCLUDE_TESTS=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=$<IF:${LLVM_TARGET},${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/clang++,${CMAKE_CXX_COMPILER}>
    -DCMAKE_C_COMPILER=$<IF:${LLVM_TARGET},${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/clang,${CMAKE_C_COMPILER}>
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
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

