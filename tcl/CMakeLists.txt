if (USE_BRLCAD)

  # Decide if we're using Tcl
  cad_enable(TCL "libtclcad;liboptical;libdm;${BEXT_TK_COMPONENTS}")

  # Tcl is selected before Tk, but system-stack acceptance must know whether
  # this component set needs the Tk/Itk half of the stack.
  cad_enable(TK "${BEXT_TK_COMPONENTS}")

else (USE_BRLCAD)

  # Unless we have ENABLE_ALL set, base the building of tcl on
  # the system detection results
  bext_enable_all_default(TCL tcl)

endif (USE_BRLCAD)

# minimum version of Tcl supported
set(TCL_MAJOR_VERSION 8)
set(TCL_MINOR_VERSION 6)
set(TCL_VERSION "${TCL_MAJOR_VERSION}.${TCL_MINOR_VERSION}")


# FIXME: Build currently fails hard on MacOS if allowed to use system Tcl
# due to incompatibilities with Itcl and inconsistent flags, so we turn
# building on unless it was specifically turned off apriori.
if (APPLE)
  if (NOT DEFINED ENABLE_TCL)
    set(ENABLE_TCL ON)
  endif (NOT DEFINED ENABLE_TCL)
endif (APPLE)


if (NOT ENABLE_TCL AND NOT DISABLE_TCL)
  set(BEXT_TCLTK_SYSTEM_STACK OFF CACHE INTERNAL "System Tcl/Tk/Itcl/Itk stack passed validation" FORCE)
  set(BEXT_ITCL_VERSION "" CACHE INTERNAL "Detected Itcl version" FORCE)
  set(BEXT_ITK_VERSION "" CACHE INTERNAL "Detected Itk version" FORCE)
  set(BEXT_ITCL_CONFIG_DIR "" CACHE INTERNAL
    "Directory containing bundled itclConfig.sh" FORCE)
  set(BEXT_ITCL_SOURCE_DIR "" CACHE INTERNAL
    "Bundled Itcl source directory" FORCE)

  set(TCL_ENABLE_TK ON CACHE BOOL "enable tk")
  find_package(TCL "${TCL_VERSION}")

  set(BEXT_SYSTEM_STACK_REASON "")
  set(BEXT_SYSTEM_STACK_DETAIL "")
  if (NOT TCL_FOUND)
    set(BEXT_SYSTEM_STACK_REASON "Tcl ${TCL_VERSION} was not found")
  else ()
    execute_process(
      COMMAND ${TCL_TCLSH} ${CMAKE_CURRENT_SOURCE_DIR}/check_itcl.tcl ${BEXT_ITCL_MIN_VERSION}
      RESULT_VARIABLE ITCL_CHECK_RESULT
      OUTPUT_VARIABLE ITCL_CHECK_OUTPUT
      ERROR_VARIABLE ITCL_CHECK_ERROR
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    if (ITCL_CHECK_RESULT)
      set(BEXT_SYSTEM_STACK_REASON "system Tcl does not provide Itcl ${BEXT_ITCL_MIN_VERSION} or newer")
      string(STRIP "${ITCL_CHECK_ERROR}" BEXT_SYSTEM_STACK_DETAIL)
    else ()
      set(BEXT_ITCL_VERSION "${ITCL_CHECK_OUTPUT}" CACHE INTERNAL "Detected Itcl version" FORCE)
    endif ()
  endif ()

  # Itk uses private Tcl and Itcl interfaces plus Tk stubs.  System Tk is
  # viable only when the same system package path supplies a sufficiently
  # new Itk.  Bext must not compile Itk against an arbitrary external
  # implementation stack.
  if (NOT BEXT_SYSTEM_STACK_REASON AND NOT DISABLE_TK)
    if (NOT TK_FOUND)
      set(BEXT_SYSTEM_STACK_REASON "Tk for Tcl ${TCL_VERSION} was not found")
    else ()
      execute_process(
        COMMAND ${TCL_TCLSH} ${CMAKE_SOURCE_DIR}/tk/check_itk.tcl ${BEXT_ITK_MIN_VERSION}
        RESULT_VARIABLE ITK_CHECK_RESULT
        OUTPUT_VARIABLE ITK_CHECK_OUTPUT
        ERROR_VARIABLE ITK_CHECK_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )
      if (ITK_CHECK_RESULT)
        set(BEXT_SYSTEM_STACK_REASON "system Tk does not provide Itk ${BEXT_ITK_MIN_VERSION} or newer")
        string(STRIP "${ITK_CHECK_ERROR}" BEXT_SYSTEM_STACK_DETAIL)
      else ()
        set(BEXT_ITK_VERSION "${ITK_CHECK_OUTPUT}" CACHE INTERNAL "Detected Itk version" FORCE)
        set(BEXT_TCLTK_SYSTEM_STACK ON CACHE INTERNAL "System Tcl/Tk/Itcl/Itk stack passed validation" FORCE)
      endif ()
    endif ()
  endif ()

  if (BEXT_SYSTEM_STACK_REASON)
    if (NOT DEFINED ENABLE_TCL)
      message(STATUS "${BEXT_SYSTEM_STACK_REASON}; enabling bundled Tcl/Tk/Itcl/Itk stack")
      set(ENABLE_TCL "ON" CACHE BOOL "Enable tcl build")
    else ()
      message(FATAL_ERROR
        "${BEXT_SYSTEM_STACK_REASON}.  Install a complete compatible system "
        "Tcl/Tk/Itcl/Itk stack or enable the bundled stack with "
        "-DENABLE_TCL=ON.\n${BEXT_SYSTEM_STACK_DETAIL}"
        )
    endif ()
  endif ()

endif (NOT ENABLE_TCL AND NOT DISABLE_TCL)
set(ENABLE_TCL "${ENABLE_TCL}" CACHE BOOL "Enable tcl build")
set(DISABLE_TCL "${DISABLE_TCL}" CACHE BOOL "Disable tcl build")

if (ENABLE_TCL)

  git_submodule_init(tcl unix/configure)
  if (NOT EXISTS "${BEXT_ITCL_BUNDLED_SOURCE_DIR}/configure")
    message(FATAL_ERROR
      "The bundled Tcl source does not contain the expected Itcl "
      "${BEXT_ITCL_BUNDLED_VERSION} sources.  Use the complete Tcl source "
      "distribution rather than the core-only source tree."
      )
  endif ()

  set(TCL_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/TCL_BLD-prefix/src/TCL_BLD")
  set(TCL_BIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/TCL_BLD-prefix/src/TCL_BLD-build")

  set(BEXT_TCLTK_SYSTEM_STACK OFF CACHE INTERNAL "System Tcl/Tk/Itcl/Itk stack passed validation" FORCE)
  set(BEXT_ITCL_VERSION "${BEXT_ITCL_BUNDLED_VERSION}" CACHE INTERNAL "Bundled Itcl version" FORCE)
  set(BEXT_ITCL_CONFIG_DIR
    "${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}/itcl${BEXT_ITCL_BUNDLED_VERSION}"
    CACHE INTERNAL "Directory containing bundled itclConfig.sh" FORCE)
  set(BEXT_ITCL_SOURCE_DIR
    "${TCL_SRC_DIR}/pkgs/itcl${BEXT_ITCL_BUNDLED_VERSION}"
    CACHE INTERNAL "Bundled Itcl source directory" FORCE)


  RegisterDeps(TCL)

  if (TARGET ZLIB_BLD)
    set(ZLIB_SETUP_COMMANDS
      ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl-z_brl.patch
      COMMAND ${CMAKE_COMMAND};-E;remove_directory;<SOURCE_DIR>/compat/zlib
      )
  endif (TARGET ZLIB_BLD)

  # For OSX, we need to adjust the rpath of tclsh in order for tkhtml's build to
  # succeed
  if (APPLE)
    set(RPATH_CMD "COMMAND;install_name_tool;-add_rpath;@executable_path/../${LIB_DIR};${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/tclsh${TCL_VERSION}${CMAKE_EXECUTABLE_SUFFIX}")
  endif (APPLE)

  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tcl_configure.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tcl_configure.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tcl_build.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tcl_build.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tcl_install.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tcl_install.cmake @ONLY)

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
      # Tcl's fallback zlib can silently supply headers even when we intend to
      # use z_brl.  Remove it only from this staging copy after patching Tcl to
      # require z_brl; the pristine source distribution remains untouched.
      COMMAND ${ZLIB_SETUP_COMMANDS}
      CONFIGURE_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tcl_configure.cmake

      # NOTE: Forcing -j on all sub-make calls to work around cmake+make
      # jobserver mode bug.  Tcl also seems to have a race fixed via genstubs.

      BUILD_COMMAND ${BEXT_MAKE_COMMAND} -j${pcnt}
      INSTALL_COMMAND ${BEXT_MAKE_COMMAND} -j1 genstubs install
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

    # wipe out any errant CC setting
    set(CC)

    ExternalProject_Add(TCL_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/tcl"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl.patch
      COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl_disable_docs.patch
      CONFIGURE_COMMAND ""
      BINARY_DIR ${TCL_SRC_DIR}/win
      BUILD_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tcl_build.cmake
      INSTALL_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tcl_install.cmake
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
