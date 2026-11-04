# Decide if we're using GeometricTools
cad_enable(GTE "libbg")

unset(GTE_BUNDLED CACHE)

if (NOT ENABLE_GTE AND NOT DISABLE_GTE)

  # https://github.com/davideberly/GeometricTools
  find_package(GTE)

  if (NOT TARGET GTE::GTE)
    set(ENABLE_GTE "ON" CACHE BOOL "Enable GeometricTools build")
  endif (NOT TARGET GTE::GTE)

endif (NOT ENABLE_GTE AND NOT DISABLE_GTE)

set(ENABLE_GTE "${ENABLE_GTE}" CACHE BOOL "Enable GeometricTools build")

# Decision made

if (ENABLE_GTE)

  set(GTE_PATCH_FILES "${CMAKE_CURRENT_SOURCE_DIR}/gte.patch")
  git_submodule_init(GeometricTools GTE/CMakeLists.txt
    PATCH_FILES ${GTE_PATCH_FILES}
    PATCH_COMMAND_VAR GTE_PATCH_COMMAND)

  RegisterDeps(GTE)

  ExternalProject_Add(GTE_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/GeometricTools"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${GTE_PATCH_COMMAND}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(GTE GTE_DEPENDS)

  set(GTE_BUNDLED TRUE CACHE BOOL "GeometricTools bundle flag")

endif (ENABLE_GTE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

