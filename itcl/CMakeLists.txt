if (USE_BRLCAD)

  # Decide if we're using ITcl
  cad_enable(ITCL "archer;mged;bwish;rtwizard;brlman")

else (USE_BRLCAD)

  if (ENABLE_TCL AND NOT DEFINED ENABLE_ITCL)
    set(ENABLE_ITCL ON)
  endif (ENABLE_TCL AND NOT DEFINED ENABLE_ITCL)

endif (USE_BRLCAD)

if (NOT ENABLE_ITCL AND NOT DEFINED DISABLE_ITCL)

  find_package(ITCL)

  if (NOT ITCL_FOUND AND NOT DEFINED ENABLE_ITCL)
    set(ENABLE_ITCL "ON" CACHE BOOL "Enable itcl build")
  endif (NOT ITCL_FOUND AND NOT DEFINED ENABLE_ITCL)

endif (NOT ENABLE_ITCL AND NOT DEFINED DISABLE_ITCL)
set(ENABLE_ITCL "${ENABLE_ITCL}" CACHE BOOL "Enable itcl build")

if (ENABLE_ITCL)

  git_submodule_init(itcl configure.in)

  TargetDeps(ITCL)

  # If we're building ITCL, it's path setup must take into account the
  # subdirectory in which we are storing the library.
  set(RPATH_SUFFIX itcl3.4)

  ExternalProject_Add(ITCL_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/itcl"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/itcl.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=$<IF:$<BOOL:${WIN32}>,${LIB_DIR},${BIN_DIR}>
    -DLIB_DIR=${LIB_DIR}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}/${RPATH_SUFFIX}
    -DINCLUDE_DIR=${INCLUDE_DIR}
    -DSHARED_DIR=${LIB_DIR}
    -DTCL_ENABLE_TK=ON
    -DTCL_ROOT=$<$<BOOL:${TCL_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DTCL_SOURCE_DIR=${CMAKE_SOURCE_DIR}/tcl/tcl
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(ITCL ITCL_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/itcl/license.terms
    ${DOC_LICENSE_DIR}/itcl3.txt
    COPYONLY
    )

endif (ENABLE_ITCL)

mark_as_advanced(ITCL_LIBRARY)
mark_as_advanced(ITCL_LIBRARIES)
mark_as_advanced(ITCL_VERSION)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

