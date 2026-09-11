if (USE_BRLCAD)

  # Decide if we're using Tcl
  cad_enable(IWIDGETS "archer;mged")

endif (USE_BRLCAD)

# Tcl can inspect a system package index without loading Iwidgets, but the
# advertised version does not establish Itcl 4 compatibility.  The latest
# upstream 4.1.1 sources still need the fixes in iwidgets_itcl4.patch, and a
# system package using that same version may or may not carry equivalent
# downstream fixes.  Actually validating it loads Tk and requires a display.
# Unless explicitly disabled, use the known patched copy.

if (NOT DEFINED ENABLE_IWIDGETS AND NOT DISABLE_IWIDGETS)
  set(ENABLE_IWIDGETS ON)
endif (NOT DEFINED ENABLE_IWIDGETS AND NOT DISABLE_IWIDGETS)

if (ENABLE_IWIDGETS)

  git_submodule_init(iwidgets CMakeLists.txt)

  RegisterDeps(IWIDGETS)

  ExternalProject_Add(IWIDGETS_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/iwidgets"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/iwidgets_itcl4.patch
    CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DLIB_DIR=${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(IWIDGETS IWIDGETS_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/iwidgets/license.terms
    ${DOC_LICENSE_DIR}/iwidgets.txt
    COPYONLY
    )

endif (ENABLE_IWIDGETS)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
