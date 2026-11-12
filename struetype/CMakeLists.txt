bext_local_source(STRUETYPE struetype https://github.com/starseeker/struetype 4e9369d550f0849f58b27dc6e3db8fc2d54e8304)

if (ENABLE_STRUETYPE)
  RegisterDeps(STRUETYPE)
  configure_file(install.cmake.in InstallStruetype.cmake @ONLY)
  ExternalProject_Add(STRUETYPE_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/struetype"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
      -P "${CMAKE_CURRENT_BINARY_DIR}/InstallStruetype.cmake"
    STEP_TARGETS install
    )
  TargetInstallDeps(STRUETYPE STRUETYPE_DEPENDS)
  configure_file(struetype/LICENSE "${DOC_LICENSE_DIR}/struetype.txt" COPYONLY)
endif ()
