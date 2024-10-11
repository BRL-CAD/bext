# Decide if we're using osmesa
cad_enable(OSMESA "libdm")

bext_enable(OSMESA)

# Decision made

if (ENABLE_OSMESA)

  git_submodule_init(osmesa CMakeLists.txt)

  RegisterDeps(OSMESA)

  ExternalProject_Add(OSMESA_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/osmesa"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    -DOSMESA_BUILD_EXAMPLES=OFF
    ${BUILD_TYPE_SPECIFIER}
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

  TargetInstallDeps(OSMESA OSMESA_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/osmesa/LICENSE
    ${DOC_LICENSE_DIR}/osmesa.txt
    COPYONLY
    )

endif (ENABLE_OSMESA)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

