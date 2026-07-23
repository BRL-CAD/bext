
bext_enable(OIDN)

if (ENABLE_OIDN)

  git_submodule_init(oidn CMakeLists.txt)

  RegisterDeps(OIDN)

  ExternalProject_Add(OIDN_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/oidn"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    # OIDN's debug builds are broken upstream, so it is always built Release -
    # this matches OSPRay's own superbuild recipe (dep_oidn.cmake).
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_PREFIX_PATH=${CMAKE_BUNDLE_INSTALL_PREFIX}
    $<$<BOOL:${ONETBB_TARGET}>:-DTBB_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${ISPC_TARGET}>:-DISPC_EXECUTABLE=${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/ispc${CMAKE_EXECUTABLE_SUFFIX}>
    -DOIDN_APPS=OFF
    -DOIDN_ZIP_MODE=ON
    -DOIDN_DEVICE_SYCL=OFF
    # Force a shared OIDN even though bext defaults BUILD_STATIC_LIBS=ON: OSPRay's
    # denoiser module (and OSPRay's own superbuild) expect shared OIDN, and a
    # static OIDN risks its self-registering CPU device being stripped by the
    # MSVC linker, leaving no device available at runtime.
    -DOIDN_STATIC_LIB=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_BINDIR:PATH=${BIN_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(OIDN OIDN_DEPENDS)
  # ISPC is only produced when a renderer group (e.g. OSPRAY) is active, so wire
  # the ordering dependency explicitly the same way embree does.
  if (TARGET ISPC_BLD)
    ExternalProject_Add_stepdependencies(OIDN_BLD configure ISPC_BLD-install)
  endif (TARGET ISPC_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/oidn/LICENSE.txt
    ${DOC_LICENSE_DIR}/oidn.txt
    COPYONLY
    )

endif (ENABLE_OIDN)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
