# Decide if we're using tinygltf
cad_enable(TINYGLTF "librt;libgcv")

unset(ENGEN_BUNDLED CACHE)

if (NOT ENABLE_TINYGLTF AND NOT DISABLE_TINYGLTF)

  find_package(tinygltf NO_MODULE)

  if (NOT TARGET tinygltf::tinygltf)
    set(ENABLE_TINYGLTF "ON" CACHE BOOL "Enable tinygltf build")
  endif (NOT TARGET tinygltf::tinygltf)

endif (NOT ENABLE_TINYGLTF AND NOT DISABLE_TINYGLTF)

set(ENABLE_TINYGLTF "${ENABLE_TINYGLTF}" CACHE BOOL "Enable tinygltf build")

# Decision made

if (ENABLE_TINYGLTF)

  git_submodule_init(tinygltf CMakeLists.txt)

  RegisterDeps(TINYGLTF)

  ExternalProject_Add(TINYGLTF_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/tinygltf"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tinygltf.patch
    CMAKE_ARGS
    -DTINYGLTF_BUILD_LOADER_EXAMPLE=OFF
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_Fortran_COMPILER=OFF
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(TINYGLTF TINYGLTF_DEPENDS)

  set(TINYGLTF_BUNDLED TRUE CACHE BOOL "tinygltf bundle flag")

endif (ENABLE_TINYGLTF)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

