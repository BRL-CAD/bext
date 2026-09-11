# By the time we get here, we have run FindTCL and should know
# if we have TK.

set(TK_EXTRA_PATCHES "" CACHE STRING "Additional patches to apply to bundled Tk on Unix")
set(TK_CONFIGURE_ARGS "" CACHE STRING "Additional arguments for bundled Tk's Unix configure script")

if (USE_BRLCAD)

  # Decide if we're using Tk
  cad_enable(TK "archer;mged;bwish;rtwizard;brlman")

  if (NOT TK_LIBRARY OR TARGET TCL_BLD)
    set(TK_DO_BUILD 1)
  endif (NOT TK_LIBRARY OR TARGET TCL_BLD)
  if (DISABLE_TCL OR DISABLE_TK)
    set(TK_DO_BUILD 0)
  endif (DISABLE_TCL OR DISABLE_TK)

else (USE_BRLCAD)

  if (NOT DISABLE_TCL)
    if (NOT TK_LIBRARY OR TARGET TCL_BLD)
      set(TK_DO_BUILD 1)
    else (NOT TK_LIBRARY OR TARGET TCL_BLD)
      set(TK_DO_BUILD 0)
    endif (NOT TK_LIBRARY OR TARGET TCL_BLD)
  else (NOT DISABLE_TCL)
    set(TK_DO_BUILD 0)
  endif (NOT DISABLE_TCL)

endif(USE_BRLCAD)

if (BEXT_XMIN_ROOT AND NOT DISABLE_TCL AND NOT DISABLE_TK)
  set(TK_DO_BUILD 1)
  set(tk_xmin_patch "${CMAKE_CURRENT_SOURCE_DIR}/tk_xmin.patch")
  list(PREPEND TK_EXTRA_PATCHES "${tk_xmin_patch}")
  list(REMOVE_DUPLICATES TK_EXTRA_PATCHES)
  set(tk_xmin_configure_arg "--with-xmin=${BEXT_XMIN_ROOT}")
  list(FIND TK_CONFIGURE_ARGS "${tk_xmin_configure_arg}" tk_xmin_arg_index)
  if (tk_xmin_arg_index EQUAL -1)
    list(APPEND TK_CONFIGURE_ARGS "${tk_xmin_configure_arg}")
  endif ()
endif ()

if (TK_DO_BUILD)

  git_submodule_init(tk unix/configure)

  RegisterDeps(TK)

  if (NOT DEFINED TCL_VERSION)
    set(TCL_VERSION "8.6")
  endif (NOT DEFINED TCL_VERSION)

  if (TARGET TCL_BLD)
    # If we're building against a compiled Tcl and not a system Tcl,
    # set some vars accordingly
    set(TCL_SRC_DIR "${CMAKE_BINARY_DIR}/tcl/TCL_BLD-prefix/src/TCL_BLD")
    set(WITH_TCL_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}")
  else (TARGET TCL_BLD)
    get_filename_component(TCLCONF_DIR "${TCL_LIBRARY}" DIRECTORY)
    # Need the directory with tclConfig.sh
    set(WITH_TCL_DIR "${TCLCONF_DIR}")
    if (NOT EXISTS "${WITH_TCL_DIR}/tclConfig.sh")
      set(WITH_TCL_DIR "${TCLCONF_DIR}/tcl${TCL_VERSION}")
      if (NOT EXISTS "${WITH_TCL_DIR}/tclConfig.sh")
	message(WARNING "Trying to use system Tcl, but tclConfig.sh not found!")
      endif ()
    endif ()
  endif (TARGET TCL_BLD)

  set(TK_SOURCE_ARGUMENTS URL "${CMAKE_CURRENT_SOURCE_DIR}/tk")
  set(TK_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/TK_BLD-prefix/src/TK_BLD")
  set(TK_BIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/TK_BLD-prefix/src/TK_BLD-build")

  if (NOT MSVC)
    set(TK_PATCH_FILES
      "${CMAKE_CURRENT_SOURCE_DIR}/tk.patch"
      "${CMAKE_CURRENT_SOURCE_DIR}/tk_disable_docs.patch"
      )
    foreach(TK_EXTRA_PATCH IN LISTS TK_EXTRA_PATCHES)
      if (NOT IS_ABSOLUTE "${TK_EXTRA_PATCH}")
        message(FATAL_ERROR "TK_EXTRA_PATCHES entries must be absolute paths: ${TK_EXTRA_PATCH}")
      endif ()
      if (NOT EXISTS "${TK_EXTRA_PATCH}")
        message(FATAL_ERROR "Additional Tk patch does not exist: ${TK_EXTRA_PATCH}")
      endif ()
      list(APPEND TK_PATCH_FILES "${TK_EXTRA_PATCH}")
    endforeach()

    set(TK_PATCH_COMMAND)
    set(tk_patch_hash_input "")
    foreach(TK_PATCH_FILE IN LISTS TK_PATCH_FILES)
      file(SHA256 "${TK_PATCH_FILE}" tk_patch_hash)
      string(APPEND tk_patch_hash_input "${TK_PATCH_FILE}:${tk_patch_hash}\n")
      if (NOT TK_PATCH_COMMAND)
        set(TK_PATCH_COMMAND
          ${PATCH_EXECUTABLE} -E -p1 ${PATCH_OPTIONS} -i ${TK_PATCH_FILE}
          )
      else ()
        list(APPEND TK_PATCH_COMMAND
          COMMAND ${PATCH_EXECUTABLE} -E -p1 ${PATCH_OPTIONS} -i ${TK_PATCH_FILE}
          )
      endif ()
    endforeach()
    string(SHA256 TK_PATCH_SIGNATURE "${tk_patch_hash_input}")
    string(SUBSTRING "${TK_PATCH_SIGNATURE}" 0 12 tk_patch_short_hash)
    string(SHA256 TK_CONFIG_SIGNATURE
      "${TK_PATCH_SIGNATURE}|${TK_CONFIGURE_ARGS}")
    string(SUBSTRING "${TK_CONFIG_SIGNATURE}" 0 12 tk_config_short_hash)
    set(TK_SRC_DIR
      "${CMAKE_CURRENT_BINARY_DIR}/TK_BLD-prefix/src/TK_BLD-${tk_patch_short_hash}")
    set(TK_BIN_DIR
      "${CMAKE_CURRENT_BINARY_DIR}/TK_BLD-prefix/src/TK_BLD-build-${tk_config_short_hash}")
    set(TK_SOURCE_ARGUMENTS
      URL "${CMAKE_CURRENT_SOURCE_DIR}/tk"
      SOURCE_DIR "${TK_SRC_DIR}"
        )
  elseif (TK_EXTRA_PATCHES OR TK_CONFIGURE_ARGS)
    message(FATAL_ERROR "TK_EXTRA_PATCHES and TK_CONFIGURE_ARGS are supported only on Unix")
  endif ()

  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tk_configure.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tk_configure.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tk_build.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tk_build.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/tk_install.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/tk_install.cmake @ONLY)

  if (NOT MSVC)

    # Check for spaces in the source and build directories - those won't work
    # reliably with the Tk autotools based build.
    if ("${CMAKE_CURRENT_SOURCE_DIR}" MATCHES ".* .*")
      message(FATAL_ERROR "Bundled Tk enabled, but the path \"${CMAKE_CURRENT_SOURCE_DIR}\" contains spaces.  On this platform, Tk uses autotools to build; paths with spaces are not supported.  To continue relocate your source directory to a path that does not use spaces.")
    endif ("${CMAKE_CURRENT_SOURCE_DIR}" MATCHES ".* .*")
    if ("${CMAKE_CURRENT_BINARY_DIR}" MATCHES ".* .*")
      message(FATAL_ERROR "Bundled Tk enabled, but the path \"${CMAKE_CURRENT_BINARY_DIR}\" contains spaces.  On this platform, Tk uses autotools to build; paths with spaces are not supported.  To continue you must select a build directory with a path that does not use spaces.")
    endif ("${CMAKE_CURRENT_BINARY_DIR}" MATCHES ".* .*")

    ExternalProject_Add(TK_BLD
      ${TK_SOURCE_ARGUMENTS}
      BINARY_DIR "${TK_BIN_DIR}"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${TK_PATCH_COMMAND}
      CONFIGURE_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tk_configure.cmake

      # NOTE: Forcing -j on all sub-make calls to work around cmake+make
      # jobserver mode bug.

      BUILD_COMMAND ${BEXT_MAKE_COMMAND} -j${pcnt}
      INSTALL_COMMAND ${BEXT_MAKE_COMMAND} -j1 install
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    set(TK_APPINIT tkAppInit.c)

  else (NOT MSVC)

    ExternalProject_Add(TK_BLD
      ${TK_SOURCE_ARGUMENTS}
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tk.patch
      COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tk_disable_docs.patch
      CONFIGURE_COMMAND ""
      BINARY_DIR ${TK_SRC_DIR}/win
      BUILD_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tk_build.cmake
      INSTALL_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tk_install.cmake
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    set(TK_APPINIT)

  endif (NOT MSVC)

  # The library file permissions end up a bit strange - fix them
  find_program(CHMOD_EXECUTABLE chmod)
  mark_as_advanced(CHMOD_EXECUTABLE)
  if (CHMOD_EXECUTABLE)
    if (MSVC)
      set(LIB_PREFIX)
      set(SHARED_DIR ${BIN_DIR})
      set(TCL_VERSION "86")
    else (MSVC)
      set(LIB_PREFIX "lib")
      set(SHARED_DIR ${LIB_DIR})
    endif (MSVC)
    add_custom_target(tk_permissionsfix ALL
      COMMAND ${CHMOD_EXECUTABLE} a-x,u+w ${CMAKE_BUNDLE_INSTALL_PREFIX}/${SHARED_DIR}/${LIB_PREFIX}tk${TCL_VERSION}${CMAKE_SHARED_LIBRARY_SUFFIX}
      COMMAND ${CHMOD_EXECUTABLE} a-x,u+w ${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}/${LIB_PREFIX}tkstub${TCL_VERSION}${CMAKE_STATIC_LIBRARY_SUFFIX}
      DEPENDS TK_BLD-install
      )
  endif (CHMOD_EXECUTABLE)

  TargetInstallDeps(TK TK_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/tk/license.terms
    ${DOC_LICENSE_DIR}/tk.txt
    COPYONLY
    )

endif (TK_DO_BUILD)

mark_as_advanced(TK_INCLUDE_DIRS)
mark_as_advanced(TK_LIBRARIES)
mark_as_advanced(TK_X11_GRAPHICS)
mark_as_advanced(HAVE_TK)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
