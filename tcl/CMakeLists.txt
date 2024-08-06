if (USE_BRLCAD)

  # Decide if we're using Tcl
  cad_enable(TCL "libtclcad")

else (USE_BRLCAD)

  # Unless we have ENABLE_ALL set, base the building of tcl on
  # the system detection results
  if (ENABLE_ALL AND NOT DEFINED ENABLE_TCL)
    set(ENABLE_TCL ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_TCL)

endif (USE_BRLCAD)

# minimum version of Tcl supported
set(TCL_MAJOR_VERSION 8)
set(TCL_MINOR_VERSION 6)
set(TCL_VERSION "${TCL_MAJOR_VERSION}.${TCL_MINOR_VERSION}")

if (NOT ENABLE_TCL AND NOT DISABLE_TCL)

  set(TCL_ENABLE_TK ON CACHE BOOL "enable tk")
  set(CMAKE_FIND_FRAMEWORK NEVER)
  find_package(TCL $TCL_VERSION)

  if (NOT TCL_FOUND AND NOT DEFINED ENABLE_TCL)
    set(ENABLE_TCL "ON" CACHE BOOL "Enable tcl build")
  endif (NOT TCL_FOUND AND NOT DEFINED ENABLE_TCL)

endif (NOT ENABLE_TCL AND NOT DISABLE_TCL)
set(ENABLE_TCL "${ENABLE_TCL}" CACHE BOOL "Enable tcl build")
set(DISABLE_TCL "${DISABLE_TCL}" CACHE BOOL "Disable tcl build")

if (ENABLE_TCL)

  git_submodule_init(tcl unix/configure)

  TargetDeps(TCL)

  set(TCL_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/TCL_BLD-prefix/src/TCL_BLD")
  set(TCL_BIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/TCL_BLD-prefix/src/TCL_BLD-build")

  if (TARGET ZLIB_BLD)
    set(ZLIB_PATCH_CMD ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl-z_brl.patch)
  endif (TARGET ZLIB_BLD)

  # For OSX, we need to adjust the rpath of tclsh in order for tkhtml's build to
  # succeed
  if (APPLE)
    set(RPATH_CMD "COMMAND;install_name_tool;-add_rpath;@executable_path/../${LIB_DIR};${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/tclsh${TCL_VERSION}${CMAKE_EXECUTABLE_SUFFIX}")
  endif (APPLE)

  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tcl_configure.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tcl_configure.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tcl_build.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tcl_build.cmake @ONLY)

  if (NOT MSVC)

    # Check for spaces in the source and build directories - those won't work
    # reliably with the Tcl autotools based build.
    if ("${CMAKE_CURRENT_SOURCE_DIR}" MATCHES ".* .*")
      message(FATAL_ERROR "Bundled Tcl enabled, but the path \"${CMAKE_CURRENT_SOURCE_DIR}\" contains spaces.  On this platform, Tcl uses autotools to build; paths with spaces are not supported.  To continue relocate your source directory to a path that does not use spaces.")
    endif ("${CMAKE_CURRENT_SOURCE_DIR}" MATCHES ".* .*")
    if ("${CMAKE_CURRENT_BINARY_DIR}" MATCHES ".* .*")
      message(FATAL_ERROR "Bundled Tcl enabled, but the path \"${CMAKE_CURRENT_BINARY_DIR}\" contains spaces.  On this platform, Tcl uses autotools to build; paths with spaces are not supported.  To continue you must select a build directory with a path that does not use spaces.")
    endif ("${CMAKE_CURRENT_BINARY_DIR}" MATCHES ".* .*")

    ExternalProject_Add(TCL_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/tcl"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl.patch
      COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl_disable_docs.patch
      COMMAND ${ZLIB_PATCH_CMD}
      CONFIGURE_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tcl_configure.cmake

      # NOTE: Forcing -j on all sub-make calls to work around cmake+make
      # jobserver mode bug.  Tcl also seems to have a race fixed via genstubs.

      BUILD_COMMAND make -j${pcnt}
      INSTALL_COMMAND make -j1 genstubs install
      ${RPATH_CMD}
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    set(TCL_APPINIT tclAppInit.c)

  else (NOT MSVC)

    # TODO - how to pass Z_PREFIX through nmake so zlib.h has the correct
    # prefix?  Is https://stackoverflow.com/a/11041834 what we need?  Also, do
    # we need to patch makefile.vc to reference our zlib dll?

    ExternalProject_Add(TCL_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/tcl"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl.patch
      COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl_disable_docs.patch
      CONFIGURE_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tcl_configure.cmake
      BINARY_DIR ${TCL_SRC_DIR}/win
      BUILD_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tcl_build.cmake
      INSTALL_COMMAND ${VCVARS_BAT} && nmake -f makefile.vc install INSTALLDIR=${CMAKE_BUNDLE_INSTALL_PREFIX} SUFX=
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )
    set(TCL_APPINIT)

  endif (NOT MSVC)

  TargetInstallDeps(TCL TCL_DEPENDS)

  # Scripts expect a non-versioned tclsh program, but the Tcl build doesn't provide one,
  # we must provide it ourselves
  if (MSVC)
    add_custom_target(tclsh_cpy ALL
      COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/tclsh${TCL_MAJOR_VERSION}${TCL_MINOR_VERSION}${CMAKE_EXECUTABLE_SUFFIX} ${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/tclsh${CMAKE_EXECUTABLE_SUFFIX}
      DEPENDS TCL_BLD-install
      )
  else (MSVC)
    add_custom_target(tclsh_cpy ALL
      COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/tclsh${TCL_VERSION}${CMAKE_EXECUTABLE_SUFFIX} ${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/tclsh${CMAKE_EXECUTABLE_SUFFIX}
      DEPENDS TCL_BLD-install
      )
  endif (MSVC)

  # The library file permissions end up a bit strange - fix them
  find_program(CHMOD_EXECUTABLE chmod)
  mark_as_advanced(CHMOD_EXECUTABLE)
  if (CHMOD_EXECUTABLE)
    if (MSVC)
      set(LIB_PREFIX)
      set(SHARED_DIR ${BIN_DIR})
      set(TCL_VERSION "${TCL_MAJOR_VERSION}${TCL_MINOR_VERSION}")
    else (MSVC)
      set(LIB_PREFIX "lib")
      set(SHARED_DIR ${LIB_DIR})
    endif (MSVC)
    add_custom_target(tcl_permissionsfix ALL
      COMMAND ${CHMOD_EXECUTABLE} a-x,u+w ${CMAKE_BUNDLE_INSTALL_PREFIX}/${SHARED_DIR}/${LIB_PREFIX}tcl${TCL_VERSION}${CMAKE_SHARED_LIBRARY_SUFFIX}
      COMMAND ${CHMOD_EXECUTABLE} a-x,u+w ${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}/${LIB_PREFIX}tclstub${TCL_VERSION}${CMAKE_STATIC_LIBRARY_SUFFIX}
      DEPENDS TCL_BLD-install
      )
  endif (CHMOD_EXECUTABLE)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/tcl/license.terms
    ${DOC_LICENSE_DIR}/tcl.txt
    COPYONLY
    )

endif (ENABLE_TCL)

mark_as_advanced(TCL_INCLUDE_DIRS)
mark_as_advanced(TCL_LIBRARIES)
mark_as_advanced(TCL_VERSION)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8


