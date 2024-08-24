# tiff is needed by GDAL, which is used by libgcv.  TODO: Probably ought to
# wire this into libicv as well if we're going to have it along for the ride...
cad_enable(TIFF "libgcv;libicv")

bext_enable(TIFF)

# Decision made

if (ENABLE_TIFF)

  git_submodule_init(libtiff CMakeLists.txt)

  RegisterDeps(TIFF)
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
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/libtiff/LICENSE.md
    ${DOC_LICENSE_DIR}/tiff.txt
    COPYONLY
    )

endif (ENABLE_TIFF)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

