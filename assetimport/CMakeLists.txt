# Decide if we're using assetimport.
# Also, assetimport is used directly by a libgcv plugin and (until we update to Manifold 3.0)
# is needed by Manifold, which is used by librt
cad_enable(ASSETIMPORT "libgcv;librt")

bext_enable(ASSETIMPORT)

# Decision made

if (ENABLE_ASSETIMPORT)

  git_submodule_init(assimp CMakeLists.txt)

  RegisterDeps(ASSETIMPORT)
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)

  # bext: assimp's inner CMakeLists sets -Werror; many of its headers and
  # bundled third-party sources (utf8cpp, stb_image, cxxopts, assjson/*.c...)
  # trigger Clang 20+ warnings that MSVC cl.exe doesn't implement: -Wpadded,
  # -Wunsafe-buffer-usage(-in-libc-call), -Wswitch-default, -Wlifetime-bound,
  # etc.  Whack-a-mole per warning is fragile; instead we globally disable
  # -Werror on Clang so assimp's own -Werror flag becomes advisory.  MSVC
  # cl.exe and GCC (both of which don't hit these particular new-Clang
  # warnings) are untouched.  Apply to BOTH CMAKE_C_FLAGS_INIT and
  # CMAKE_CXX_FLAGS_INIT since assjson/cencode.c is C, not C++.  Additive
  # so CMake's default flags are preserved.
  set(ASSETIMPORT_BEXT_C_FLAGS_INIT "")
  set(ASSETIMPORT_BEXT_CXX_FLAGS_INIT "")
  if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    if (MSVC)
      set(ASSETIMPORT_BEXT_C_FLAGS_INIT "/clang:-Wno-error")
    else ()
      set(ASSETIMPORT_BEXT_C_FLAGS_INIT "-Wno-error")
    endif ()
  endif ()
  if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    if (MSVC)
      set(ASSETIMPORT_BEXT_CXX_FLAGS_INIT "/clang:-Wno-error")
    else ()
      set(ASSETIMPORT_BEXT_CXX_FLAGS_INIT "-Wno-error")
    endif ()
  endif ()

  ExternalProject_Add(ASSETIMPORT_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/assimp"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/assetimport_CMake.patch
    COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/assetimport_stb.patch
    COMMAND ${CMAKE_COMMAND};-E;remove;<SOURCE_DIR>/cmake-modules/FindZLIB.cmake
    COMMAND ${CMAKE_COMMAND};-E;copy;${PROJECT_SOURCE_DIR}/CMake/FindZLIB.cmake;<SOURCE_DIR>/cmake-modules/FindZLIB.cmake
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DCMAKE_C_FLAGS_INIT=${ASSETIMPORT_BEXT_C_FLAGS_INIT}
    -DCMAKE_CXX_FLAGS_INIT=${ASSETIMPORT_BEXT_CXX_FLAGS_INIT}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -Dpugixml_ROOT=$<$<BOOL:${PUGIXML_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DASSIMP_BUILD_USE_CCACHE=OFF
    -DASSIMP_BUILD_ASSIMP_TOOLS=OFF
    -DASSIMP_BUILD_TESTS=OFF
    -DASSIMP_BUILD_MINIZIP=ON
    -DASSIMP_BUILD_ZLIB=OFF
    -DASSIMP_INJECT_DEBUG_POSTFIX=OFF
    -DASSIMP_INSTALL_PDB=OFF
    DEPENDS ${ASSETIMPORT_DEPS}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(ASSETIMPORT ASSETIMPORT_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/assimp/LICENSE
    ${DOC_LICENSE_DIR}/assetimport.txt
    COPYONLY
    )

endif (ENABLE_ASSETIMPORT)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

