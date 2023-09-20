# It looks like Windows and OSX have their own solutions for unicode...
if (NOT WIN32 AND NOT APPLE)

  # Unless we have ENABLE_ALL set, base the building of icu on
  # the system detection results
  if (ENABLE_ALL AND NOT DEFINED ENABLE_ICU)
    set(ENABLE_ICU ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_ICU)

  if (NOT ENABLE_ICU)

    find_package(ICU)

    if (NOT ICU_FOUND AND NOT DEFINED ENABLE_ICU)
      set(ENABLE_ICU "ON" CACHE BOOL "Enable icu build")
    endif (NOT ICU_FOUND AND NOT DEFINED ENABLE_ICU)

  endif (NOT ENABLE_ICU)
  set(ENABLE_ICU "${ENABLE_ICU}" CACHE BOOL "Enable icu build")

  if (ENABLE_ICU)

    git_submodule_init(icu icu4c/source/configure)

    ExternalProject_Add(ICU_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/icu"
      SOURCE_SUBDIR icu4c/source
      BUILD_IN_SOURCE ON
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      CONFIGURE_COMMAND <SOURCE_DIR>/<SOURCE_SUBDIR>/configure --disable-extras --disable-tools --disable-tests --disable-samples --disable-renaming --prefix=${CMAKE_BUNDLE_INSTALL_PREFIX}
      BUILD_COMMAND make -j${pcnt}
      INSTALL_COMMAND make install
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    if (TARGET PATCH_BLD)
      ExternalProject_Add_StepDependencies(ICU_BLD configure PATCH_BLD-install)
    endif (TARGET PATCH_BLD)

    # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
    file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
    configure_file(
      ${CMAKE_CURRENT_SOURCE_DIR}/icu/icu4c/LICENSE
      ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/icu.txt
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

