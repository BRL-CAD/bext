# By the time we get here, we have run FindTCL and should know
# if we have TK.

if (NOT TK_LIBRARY OR TARGET TCL_BLD)
  set(TK_DO_BUILD 1)
else (NOT TK_LIBRARY OR TARGET TCL_BLD)
  set(TK_DO_BUILD 0)
endif (NOT TK_LIBRARY OR TARGET TCL_BLD)

if (TK_DO_BUILD)

  git_submodule_init(tk unix/configure)

  TargetDeps(TK)

  if (TARGET TCL_BLD)
    # If we're building against a compiled Tcl and not a system Tcl,
    # set some vars accordingly
    set(TCL_SRC_DIR "${CMAKE_BINARY_DIR}/tcl/TCL_BLD-prefix/src/TCL_BLD")
  else (TARGET TCL_BLD)
    get_filename_component(TCLCONF_DIR "${TCL_LIBRARY}" DIRECTORY)
  endif (TARGET TCL_BLD)

  set(TK_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/TK_BLD-prefix/src/TK_BLD")

  if (NOT DEFINED TCL_VERSION)
    set(TCL_VERSION "8.6")
  endif (NOT DEFINED TCL_VERSION)

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
      URL "${CMAKE_CURRENT_SOURCE_DIR}/tk"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tk.patch
      COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tk_disable_docs.patch
      CONFIGURE_COMMAND LD_LIBRARY_PATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR} CPPFLAGS=-I${CMAKE_BUNDLE_INSTALL_PREFIX}/${INCLUDE_DIR} LDFLAGS=-L${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR} TK_SHLIB_LD_EXTRAS=-L${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR} ${TK_SRC_DIR}/unix/configure --prefix=${CMAKE_BUNDLE_INSTALL_PREFIX} --with-tcl=$<IF:$<BOOL:${TCL_TARGET}>,${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR},${TCLCONF_DIR}>
      BUILD_COMMAND make -j${pcnt}
      INSTALL_COMMAND make install
      # Note - LOG_CONFIGURE doesn't seem to be compatible with complex CONFIGURE_COMMAND setups
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    set(TK_APPINIT tkAppInit.c)

  else (NOT MSVC)

    ExternalProject_Add(TK_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/tk"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tk.patch
      COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tk_disable_docs.patch
      CONFIGURE_COMMAND ""
      BINARY_DIR ${TK_SRC_DIR}/win
      BUILD_COMMAND ${VCVARS_BAT} && nmake -f makefile.vc INSTALLDIR=${CMAKE_BUNDLE_INSTALL_PREFIX} TCLDIR=${TCL_SRC_DIR} SUFX=
      INSTALL_COMMAND ${VCVARS_BAT} && nmake -f makefile.vc install INSTALLDIR=${CMAKE_BUNDLE_INSTALL_PREFIX} TCLDIR=${TCL_SRC_DIR} SUFX=
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
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/tk/license.terms
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/tk.txt
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

