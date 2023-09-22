# Unless we have ENABLE_ALL set, based the building of yaml-cpp on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_YAML_CPP)
  set(ENABLE_YAML_CPP ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_YAML_CPP)

if (NOT ENABLE_YAML_CPP)

  find_package(YAML_CPP)

  if (NOT YAML_CPP_FOUND AND NOT DEFINED ENABLE_YAML_CPP)
    set(ENABLE_YAML_CPP "ON" CACHE BOOL "Enable yaml-cpp build")
  endif (NOT YAML_CPP_FOUND AND NOT DEFINED ENABLE_YAML_CPP)

endif (NOT ENABLE_YAML_CPP)
set(ENABLE_YAML_CPP "${ENABLE_YAML_CPP}" CACHE BOOL "Enable yaml-cpp build")

if (ENABLE_YAML_CPP)

  git_submodule_init(yaml-cpp CMakeLists.txt)

  ExternalProject_Add(YAML_CPP_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/yaml-cpp"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(YAML_CPP_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/yaml-cpp/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/yaml-cpp.txt
    COPYONLY
    )

endif (ENABLE_YAML_CPP)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

