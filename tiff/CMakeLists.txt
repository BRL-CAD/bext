# tiff is needed by GDAL, which is used by libgcv.  TODO: Probably ought to
# wire this into libicv as well if we're going to have it along for the ride...
cad_enable(TIFF "libgcv;libicv")

bext_enable(TIFF)

# Decision made

if (ENABLE_TIFF)

  git_submodule_init(libtiff CMakeLists.txt)

  RegisterDeps(TIFF)

  ExternalProject_Add(TIFF_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/libtiff"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tiff_cmake.patch
    CMAKE_ARGS
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    $<$<BOOL:${JPEG_TARGET}>:-DJPEG_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${ZLIB_TARGET}>:-DZLIB_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
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

