# jpeg is needed by GDAL, which is used by libgcv.  TODO: Probably ought to
# wire this into libicv as well if we're going to have it along for the ride...
cad_enable(JPEG "libgcv;libicv")

bext_enable(JPEG)

# Decision made

if (ENABLE_JPEG)

  git_submodule_init(libjpeg-turbo CMakeLists.txt)

  TargetDeps(JPEG)

  ExternalProject_Add(JPEG_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
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

  TargetInstallDeps(JPEG JPEG_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo/LICENSE.md
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/jpeg.txt
    COPYONLY
    )

endif (ENABLE_JPEG)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

