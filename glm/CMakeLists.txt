# Decide if we're using glm
cad_enable(GLM "librt")

bext_enable(GLM)

# Decision made

if (ENABLE_GLM)

  git_submodule_init(glm readme.md)

  RegisterDeps(GLM)

  ExternalProject_Add(GLM_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/glm"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/glm.patch
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

  TargetInstallDeps(GLM GLM_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/glm_mit.txt
    ${DOC_LICENSE_DIR}/glm.txt
    COPYONLY
    )

endif (ENABLE_GLM)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

