if (USE_BRLCAD)

  # Decide if we're using Tcl
  cad_enable(TKHTML "archer;mged")

endif (USE_BRLCAD)

# Unfortunately, there does not appear to be a reliable way to test for the
# presence of the Tkhtml package on a system Tcl/Tk.  We key off of the
# presence of the TK_BLD target, but that may produce a false negative if the
# Tk build is off but we still need Tkhtml.  As far as I can tell the "package
# require Tkhtml" test (which is what is required to properly test for an
# available Tkhtml package) can ONLY be performed successfully on a system that
# supports creation of a graphics window. Window creation isn't typically
# available on continuous integration runners, which means the test will always
# fail there even when it shouldn't.

# We try to find the Tkhtml library, since that's the only test we can do without
# needing the graphical invocation.  Unfortunately, even a find_library search
# looking for libTkhtml isn't completely reliable, since the presence of a shared
# library is not a guarantee it is correctly hooked into the "package require"
# mechanism of the system Tcl/Tk we want to use.  (It is possible to have more
# than one Tcl/Tk on a system - this situation is known to have occurred on the
# Mac when 3rd party package managers are used, for example.)

if (ENABLE_TK AND NOT DEFINED ENABLE_TKHTML AND NOT DISABLE_TKHTML)
  set(ENABLE_TKHTML ON)
endif (ENABLE_TK AND NOT DEFINED ENABLE_TKHTML AND NOT DISABLE_TKHTML)

if (NOT ENABLE_TKHTML)
  find_library(TKHTML_SYS_LIBRARY NAMES tkhtml Tkhtml Tkhtml3)

  if (NOT TKHTML_SYS_LIBRARY AND NOT DEFINED ENABLE_TKHTML)
    set(ENABLE_TKHTML "ON" CACHE BOOL "Enable Tkhtml build")
  endif (NOT TKHTML_SYS_LIBRARY AND NOT DEFINED ENABLE_TKHTML)

endif (NOT ENABLE_TKHTML)
set(ENABLE_TKHTML "${ENABLE_TKHTML}" CACHE BOOL "Enable Tkhtml build")

if (ENABLE_TKHTML)

  git_submodule_init(tkhtml CMakeLists.txt)

  RegisterDeps(TKHTML)

  ExternalProject_Add(TKHTML_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/tkhtml"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
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
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(TKHTML TKHTML_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/tkhtml/COPYING
    ${DOC_LICENSE_DIR}/tkhtml.txt
    COPYONLY
    )

endif (ENABLE_TKHTML)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

