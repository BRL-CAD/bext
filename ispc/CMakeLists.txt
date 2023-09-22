# Unless we have ENABLE_ALL set, based the building of openimageio on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_ISPC)
  set(ENABLE_ISPC ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_ISPC)

if (NOT ENABLE_ISPC)

  find_package(ISPC)

  if (NOT ISPC_FOUND AND NOT DEFINED ENABLE_ISPC)
    set(ENABLE_ISPC "ON" CACHE BOOL "Enable ispc build")
  endif (NOT ISPC_FOUND AND NOT DEFINED ENABLE_ISPC)

endif (NOT ENABLE_ISPC)
set(ENABLE_ISPC "${ENABLE_ISPC}" CACHE BOOL "Enable ispc build")

if (ENABLE_ISPC)

  # You may need to install some packages on Linux:
  # libc6-dev-i386
  # libstdc++-dev-i386-cross
  # gcc-multilib
  # g++-multilib

  git_submodule_init(ispc CMakeLists.txt)

  # TODO - add ncurses back in
  #set(ISPC_DEPENDS BISON FLEX LLVM NCURSES ZLIB)
  set(ISPC_DEPENDS BISON FLEX LLVM ZLIB)
  TargetVars(ISPC_DEPENDS)
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)

  # ispc depends on the clang compiler - its build will switch the compiler if
  # not already using clang.  Need to pass in the bundled LLVM clang compiler
  # location, if we have it.
  ExternalProject_Add(ISPC_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/ispc"
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/ispc.patch
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DFLEX_ROOT=$<$<BOOL:${FLEX_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DBISON_ROOT=$<$<BOOL:${BISON_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DCurses_ROOT=$<$<BOOL:${NCURSES_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DLLVM_ROOT=$<$<BOOL:${LLVM_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${LLVM_TARGET}>:-DLLVM_CONFIG_EXECUTABLE=${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/llvm-config>
    -DISPC_INCLUDE_EXAMPLES=OFF
    -DISPC_INCLUDE_DPCPP_EXAMPLES=OFF
    -DISPC_INCLUDE_TESTS=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=$<IF:${LLVM_TARGET},${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/clang++,${CMAKE_CXX_COMPILER}>
    -DCMAKE_C_COMPILER=$<IF:${LLVM_TARGET},${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/clang,${CMAKE_C_COMPILER}>
    #-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    #-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(ISPC ISPC_DEPENDS)

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(ISPC_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/ispc/LICENSE.txt
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/ispc.txt
    COPYONLY
    )

endif (ENABLE_ISPC)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

