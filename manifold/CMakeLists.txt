# Decide if we're using Manifold
cad_enable(MANIFOLD "librt;libged")

bext_enable(MANIFOLD)

# Decision made

if (ENABLE_MANIFOLD)

  git_submodule_init(manifold src/manifold/include/manifold.h)

  RegisterDeps(MANIFOLD)

  # TODO - we really should be using TBB for parallel Manifold (i.e.
  # -DMANIFOLD_PAR=TBB)
  ExternalProject_Add(MANIFOLD_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/manifold"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/manifold.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${CLIPPER2_TARGET}>:-DClipper2_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DMANIFOLD_CBIND=OFF
    -DMANIFOLD_DEBUG=ON
    -DMANIFOLD_DOWNLOADS=OFF
    -DMANIFOLD_EXPORT=OFF
    -DMANIFOLD_JSBIND=OFF
    -DMANIFOLD_OPTIMIZED=ON
    -DMANIFOLD_PAR=OFF
    -DMANIFOLD_STRICT=OFF
    -DMANIFOLD_TEST=OFF
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(MANIFOLD MANIFOLD_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/manifold/LICENSE
    ${DOC_LICENSE_DIR}/manifold.txt
    COPYONLY
    )

endif (ENABLE_MANIFOLD)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

