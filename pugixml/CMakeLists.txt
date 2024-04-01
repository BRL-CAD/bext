# Decide if we're using pugixml - used by assetimport, which
# is used by Manifold, which is used in librt
cad_enable(PUGIXML "librt")

bext_enable(PUGIXML)

# Decision made

if (ENABLE_PUGIXML)

  git_submodule_init(pugixml CMakeLists.txt)

  TargetDeps(PUGIXML)

  ExternalProject_Add(PUGIXML_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/pugixml"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
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

  TargetInstallDeps(PUGIXML PUGIXML_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/pugixml/LICENSE.md
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/pugixml.txt
    COPYONLY
    )

endif (ENABLE_PUGIXML)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

