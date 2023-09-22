# Unless we have ENABLE_ALL set, based the building of tiff on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_TIFF)
  set(ENABLE_TIFF ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_TIFF)

if (NOT ENABLE_TIFF)

  find_package(TIFF)

  if (NOT TIFF_FOUND AND NOT DEFINED ENABLE_TIFF)
    set(ENABLE_TIFF "ON" CACHE BOOL "Enable tiff build")
  endif (NOT TIFF_FOUND AND NOT DEFINED ENABLE_TIFF)

endif (NOT ENABLE_TIFF)
set(ENABLE_TIFF "${ENABLE_TIFF}" CACHE BOOL "Enable tiff build")

if (ENABLE_TIFF)

  git_submodule_init(libtiff CMakeLists.txt)

  set(TIFF_DEPENDS JPEG PATCH ZLIB)
  TargetVars(TIFF_DEPENDS)

  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)

  ExternalProject_Add(TIFF_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/libtiff"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tiff.patch
    CMAKE_ARGS
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DJPEG_ROOT=$<$<BOOL:${JPEG_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -Djbig=OFF
    -Djpeg12=OFF
    -Djpeg=ON
    -Dlerc=OFF
    -Dlibdeflate=OFF
    -Dlogluv=OFF
    -Dlzma=OFF
    -Dsphinx=OFF
    -Dtiff-contrib=OFF
    -Dtiff-docs=OFF
    -Dtiff-tests=OFF
    -Dtiff-tools=OFF
    -Dwebp=OFF
    -Dzstd=OFF
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
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

  TargetInstallDeps(TIFF TIFF_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/libtiff/LICENSE.md
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/tiff.txt
    COPYONLY
    )

endif (ENABLE_TIFF)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

