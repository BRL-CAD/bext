# Decide if we're using mmesh
cad_enable(MMESH "libbg")

bext_enable(MMESH)

# Decision made

if (ENABLE_MMESH)

  git_submodule_init(mmesh CMakeLists.txt)

  RegisterDeps(MMESH)

  ExternalProject_Add(MMESH_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/mmesh"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    -DMMESH_BUILD_EXAMPLES=OFF
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

  TargetInstallDeps(MMESH MMESH_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/mmesh/LICENSE
    ${DOC_LICENSE_DIR}/mmesh.txt
    COPYONLY
    )

endif (ENABLE_MMESH)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

