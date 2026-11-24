cad_enable(OCCT "libgcv")
bext_local_source(OCCT OCCT https://github.com/Open-Cascade-SAS/OCCT 83f9abe9477af36e4ca218e1468068aed052779f)

if (ENABLE_OCCT)
  RegisterDeps(OCCT)

  # Keep DLLs in the bundle's runtime directory for MSVC Debug builds too.
  bext_patch_command(OCCT_PATCH_COMMAND flat-unix-install.patch)

  set(occt_platform_args)
  if (APPLE)
    list(APPEND occt_platform_args -DINSTALL_NAME_DIR=@rpath)
  endif ()

  option(OCCT_BUILD_TEST_TOOLKITS "Build the OCCT toolkits for FreeCAD fixture generation" OFF)
  # OCCT adds transitive dependencies, including TKGeomBase through TKBRep.
  set(occt_toolkits TKBRep)
  if (OCCT_BUILD_TEST_TOOLKITS)
    string(APPEND occt_toolkits " TKPrim")
  endif ()

  ExternalProject_Add(OCCT_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/OCCT"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${OCCT_PATCH_COMMAND}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    ${occt_platform_args}
    -DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON
    "-DBUILD_ADDITIONAL_TOOLKITS=${occt_toolkits}"
    -DBUILD_MODULE_FoundationClasses=OFF
    -DBUILD_MODULE_ModelingData=OFF
    -DBUILD_MODULE_ModelingAlgorithms=OFF
    -DBUILD_MODULE_Visualization=OFF
    -DBUILD_MODULE_ApplicationFramework=OFF
    -DBUILD_MODULE_DataExchange=OFF
    -DBUILD_MODULE_Draw=OFF
    -DBUILD_SHARED_LIBS=ON
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    -DINSTALL_DIR_LAYOUT=Unix
    -DINSTALL_DIR_BIN=${BIN_DIR}
    -DINSTALL_DIR_LIB=${LIB_DIR}
    -DINSTALL_DIR_CMAKE=${LIB_DIR}/cmake/opencascade
    -DINSTALL_DIR_SCRIPT=share/opencascade
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
  )
  if (TARGET PATCH_BLD-install)
    ExternalProject_Add_StepDependencies(OCCT_BLD patch PATCH_BLD-install)
  endif ()

  configure_file(
    OCCT/LICENSE_LGPL_21.txt
    "${DOC_LICENSE_DIR}/occt.txt"
    COPYONLY
  )
  configure_file(
    OCCT/OCCT_LGPL_EXCEPTION.txt
    "${DOC_LICENSE_DIR}/occt-exception.txt"
    COPYONLY
  )
endif ()

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
