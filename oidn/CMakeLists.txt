
bext_enable(OIDN)

if (ENABLE_OIDN)

  set(OIDN_PATCH_FILES "${CMAKE_CURRENT_SOURCE_DIR}/oidn.patch")
  git_submodule_init(oidn CMakeLists.txt PATCH_FILES ${OIDN_PATCH_FILES})
  bext_patch_command(OIDN_FILE_PATCH_COMMAND ${OIDN_PATCH_FILES})
  if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/oidn/weights/rt_alb.tza")
    bext_git_submodule_update("${CMAKE_CURRENT_SOURCE_DIR}/oidn" -- weights)
    if (NOT BEXT_GIT_UPDATE_RESULT STREQUAL "0" OR
        NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/oidn/weights/rt_alb.tza")
      message(FATAL_ERROR "OIDN requires its pinned weights submodule")
    endif ()
  endif ()

  find_program(OIDN_GIT_EXECUTABLE git REQUIRED)
  execute_process(
    COMMAND "${OIDN_GIT_EXECUTABLE}" rev-parse HEAD
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/oidn/weights"
    RESULT_VARIABLE OIDN_WEIGHTS_REVISION_RESULT
    OUTPUT_VARIABLE OIDN_WEIGHTS_REVISION
    ERROR_VARIABLE OIDN_WEIGHTS_REVISION_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  string(LENGTH "${OIDN_WEIGHTS_REVISION}" OIDN_WEIGHTS_REVISION_LENGTH)
  if (NOT OIDN_WEIGHTS_REVISION_RESULT STREQUAL "0" OR
      NOT OIDN_WEIGHTS_REVISION_LENGTH EQUAL 40 OR
      NOT OIDN_WEIGHTS_REVISION MATCHES "^[0-9a-fA-F]+$")
    message(FATAL_ERROR
      "Unable to determine the pinned OIDN weights revision: ${OIDN_WEIGHTS_REVISION_ERROR}")
  endif ()
  set(OIDN_WEIGHTS_MEDIA_ROOT
    "https://media.githubusercontent.com/media/RenderKit/oidn-weights"
    CACHE STRING "Raw Git LFS content endpoint for the pinned OIDN weights")

  RegisterDeps(OIDN)

  # OIDN is always built Release, including in a Debug bext tree.  On MSVC,
  # oneTBB's headers otherwise auto-link tbb12.lib even when the imported
  # TBB::tbb target correctly resolves to the tree's tbb12_debug.lib.  Rely on
  # the explicit CMake target, as OIDN's fallback FindTBB module does.
  set(OIDN_CXX_FLAGS_ARGS)
  if (MSVC)
    list(APPEND OIDN_CXX_FLAGS_ARGS
      -DCMAKE_CXX_FLAGS:STRING=/D__TBB_NO_IMPLICIT_LINKAGE=1
      )
  endif (MSVC)

  ExternalProject_Add(OIDN_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/oidn"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND "${CMAKE_COMMAND}"
      -DOIDN_WEIGHTS_DIR:PATH=<SOURCE_DIR>/weights
      -DOIDN_WEIGHTS_REVISION:STRING=${OIDN_WEIGHTS_REVISION}
      -DOIDN_WEIGHTS_MEDIA_ROOT:STRING=${OIDN_WEIGHTS_MEDIA_ROOT}
      -P "${CMAKE_CURRENT_SOURCE_DIR}/HydrateWeights.cmake"
    COMMAND ${OIDN_FILE_PATCH_COMMAND}
    CMAKE_ARGS
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    # OIDN's debug builds are broken upstream, so it is always built Release -
    # this matches OSPRay's own superbuild recipe (dep_oidn.cmake).
    -DCMAKE_BUILD_TYPE=Release
    ${OIDN_CXX_FLAGS_ARGS}
    -DCMAKE_PREFIX_PATH=${CMAKE_BUNDLE_INSTALL_PREFIX}
    $<$<BOOL:${ONETBB_TARGET}>:-DTBB_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${ISPC_TARGET}>:-DISPC_EXECUTABLE=${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/ispc${CMAKE_EXECUTABLE_SUFFIX}>
    -DOIDN_APPS=OFF
    -DOIDN_ZIP_MODE=ON
    -DOIDN_DEVICE_CPU_ONEDNN=OFF
    -DOIDN_DEVICE_CUDA=OFF
    -DOIDN_DEVICE_HIP=OFF
    -DOIDN_DEVICE_SYCL=OFF
    -DOIDN_FILTER_RT=ON
    -DOIDN_FILTER_RTLIGHTMAP=ON
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

  unset(OIDN_CXX_FLAGS_ARGS)

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
