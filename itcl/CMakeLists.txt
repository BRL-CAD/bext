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

  RegisterDeps(ITCL)

  # Itcl3 has a problem in that it requires internal Tcl headers.
  # Occasionally (but not always) we can get these headers from
  # a system include path.

  if (NOT TARGET TCL_BLD)
    # If we're not building the bundled Tcl, see if the system
    # Tcl gives us the private headers.
    set(CMAKE_FIND_FRAMEWORK NEVER)
    find_package(TCL)
    set(HDRS_CANDIDATE_DIR ${TCL_INCLUDE_PATH}8.6/tcl-private)
    if (EXISTS ${HDRS_CANDIDATE_DIR})
      set(TCL_PRIVATE_HDRS ${HDRS_CANDIDATE_DIR}/generic)
      if(NOT WIN32)
	set(TCL_PRIVATE_HDRS_OS ${HDRS_CANDIDATE_DIR}/unix)
      else(NOT WIN32)
	set(TCL_PRIVATE_HDRS_OS ${HDRS_CANDIDATE_DIR}/win)
      endif(NOT WIN32)
    endif (EXISTS ${HDRS_CANDIDATE_DIR})
  endif (NOT TARGET TCL_BLD)

  # message("TCL HEADERS1:  ${TCL_PRIVATE_HDRS}")
  
  # If we can't find them from the system, see if we have a local
  # clone of Tcl to use
  if (NOT TCL_PRIVATE_HDRS AND EXISTS ${CMAKE_SOURCE_DIR}/tcl/tcl)
    set(TCL_SOURCE_DIR ${CMAKE_SOURCE_DIR}/tcl/tcl)
    set(TCL_PRIVATE_HDRS ${TCL_SOURCE_DIR}/generic)
    if(NOT WIN32)
      set(TCL_PRIVATE_HDRS_OS ${TCL_SOURCE_DIR}/unix)
    else(NOT WIN32)
      set(TCL_PRIVATE_HDRS_OS ${TCL_SOURCE_DIR}/win)
    endif(NOT WIN32)
  endif (NOT TCL_PRIVATE_HDRS AND EXISTS ${CMAKE_SOURCE_DIR}/tcl/tcl)

  # message("TCL HEADERS2:  ${TCL_PRIVATE_HDRS}")

  # If we STILL don't have anything, patch the Itcl sources to add
  # the headers in question
  set(TCL_HDRS_PATCH_CMD)
  if (NOT TCL_PRIVATE_HDRS)
    set(TCL_HDRS_PATCH_CMD ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/tcl_priv_hdrs.patch)
    set(TCL_PRIVATE_HDRS "${CMAKE_CURRENT_BINARY_DIR}/ITCL_BLD-prefix/src/ITCL_BLD/tcl_hdrs")
    if(NOT WIN32)
      set(TCL_PRIVATE_HDRS_OS ${TCL_PRIVATE_HDRS}/unix)
    else(NOT WIN32)
      set(TCL_PRIVATE_HDRS_OS ${TCL_PRIVATE_HDRS}/win)
    endif(NOT WIN32)
  endif (NOT TCL_PRIVATE_HDRS)

  # message("TCL HEADERS3:  ${TCL_PRIVATE_HDRS}")

  # When building ITCL, its path setup must take into account the subdirectory
  # in which we are storing the library.
  set(RPATH_SUFFIX itcl3.4)

  ExternalProject_Add(ITCL_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/itcl"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/itcl.patch
    COMMAND ${TCL_HDRS_PATCH_CMD}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
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
    -DTCL_PRIVATE_HDRS=${TCL_PRIVATE_HDRS}
    -DTCL_PRIVATE_HDRS_OS=${TCL_PRIVATE_HDRS_OS}
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

