# It looks like Windows and OSX have their own solutions for unicode...
if (NOT WIN32 AND NOT APPLE)

  bext_enable(ICU)

  if (ENABLE_ICU)

    git_submodule_init(icu icu4c/source/configure)

    TargetDeps(ICU)

    ExternalProject_Add(ICU_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/icu"
      SOURCE_SUBDIR icu4c/source
      BUILD_IN_SOURCE ON
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      CONFIGURE_COMMAND <SOURCE_DIR>/<SOURCE_SUBDIR>/configure --disable-extras --disable-tools --disable-tests --disable-samples --prefix=${CMAKE_BUNDLE_INSTALL_PREFIX}
      BUILD_COMMAND make -j${pcnt}
      INSTALL_COMMAND make -j1 install
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    TargetInstallDeps(FMT FMT_DEPENDS)

    # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
    configure_file(
      ${CMAKE_CURRENT_SOURCE_DIR}/icu/icu4c/LICENSE
      ${DOC_LICENSE_DIR}/icu.txt
      COPYONLY
      )

  endif (ENABLE_ICU)

endif (NOT WIN32 AND NOT APPLE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

