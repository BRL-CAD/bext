# Eigen is not bundled with BRL-CAD - it is a header only library
# and is only required at compile time,
if (ENABLE_ALL AND NOT DEFINED ENABLE_EIGEN)
  set(ENABLE_EIGEN ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_EIGEN)

if (NOT ENABLE_EIGEN)

  # https://eigen.tuxfamily.org/dox/TopicCMakeGuide.html
  find_package(Eigen3 NO_MODULE)

  if (NOT TARGET Eigen3::Eigen)
    set(ENABLE_EIGEN "ON" CACHE BOOL "Enable Eigen build")
  endif (NOT TARGET Eigen3::Eigen)

endif (NOT ENABLE_EIGEN)
set(ENABLE_EIGEN "${ENABLE_EIGEN}" CACHE BOOL "Enable Eigen build")

if (ENABLE_EIGEN)

  ExternalProject_Add(EIGEN_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/eigen"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/eigen.patch
    CMAKE_ARGS
    -DBUILD_TESTING=OFF
    -DEIGEN_BUILD_DOC=OFF
    -DEIGEN_BUILD_PKGCONFIG=OFF
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(EIGEN_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

endif (ENABLE_EIGEN)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

