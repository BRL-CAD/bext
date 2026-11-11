if (USE_BRLCAD)

  # Decide if we're using Tktable
  cad_enable(TKTABLE "archer")

endif (USE_BRLCAD)


# Loading Tktable requires a display.  Prefer a local build with bundled Tk;
# the library probe is only a fallback for an explicitly selected system stack.
if (ENABLE_TK AND NOT DEFINED ENABLE_TKTABLE AND NOT DISABLE_TKTABLE)
  set(ENABLE_TKTABLE ON)
endif (ENABLE_TK AND NOT DEFINED ENABLE_TKTABLE AND NOT DISABLE_TKTABLE)

if (NOT ENABLE_TKTABLE)
  find_library(TKTABLE_SYS_LIBRARY NAMES tktable Tktable Tktable2)

  if (NOT TKTABLE_SYS_LIBRARY AND NOT DEFINED ENABLE_TKTABLE)
    set(ENABLE_TKTABLE "ON" CACHE BOOL "Enable Tktable build")
  endif (NOT TKTABLE_SYS_LIBRARY AND NOT DEFINED ENABLE_TKTABLE)

endif (NOT ENABLE_TKTABLE)
set(ENABLE_TKTABLE "${ENABLE_TKTABLE}" CACHE BOOL "Enable Tktable build")

if (ENABLE_TKTABLE)

  # Extensions must use Tk's X11 provider, including an Xmin-backed Tk.
  set(TKTABLE_PATCH_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/tktable_tk_xlibs.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/tktable_manifest.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/tktable_relocatable.patch")
  git_submodule_init(tktable configure
    PATCH_FILES ${TKTABLE_PATCH_FILES}
    PATCH_COMMAND_VAR TKTABLE_PATCH_COMMAND)
  RegisterDeps(TKTABLE)

  set(TKTABLE_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/TKTABLE_BLD-prefix/src/TKTABLE_BLD")
  set(TKTABLE_BIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/TKTABLE_BLD-prefix/src/TKTABLE_BLD-build")

  if (MSVC)
    if (NOT TARGET TCL_BLD OR NOT TARGET TK_BLD)
      message(FATAL_ERROR
        "The native Tktable build requires bundled Tcl and Tk sources; "
        "enable them with -DENABLE_TCL=ON")
    endif ()
    set(TCL_SRC_DIR "${CMAKE_BINARY_DIR}/tcl/TCL_BLD-prefix/src/TCL_BLD")
    set(TK_SRC_DIR "${CMAKE_BINARY_DIR}/tk/TK_BLD-prefix/src/TK_BLD")
    set(TKTABLE_BIN_DIR "${TKTABLE_SRC_DIR}/win")
    configure_file(tktable_msvc.cmake.in tktable_msvc.cmake @ONLY)
    set(tktable_configure_command "")
    set(tktable_build_command
      ${CMAKE_COMMAND} -DTKTABLE_TARGET=all -P ${CMAKE_CURRENT_BINARY_DIR}/tktable_msvc.cmake)
    set(tktable_install_command
      ${CMAKE_COMMAND} -DTKTABLE_TARGET=install -P ${CMAKE_CURRENT_BINARY_DIR}/tktable_msvc.cmake)
  else ()
    foreach(package TCL TK)
      if (TARGET ${package}_BLD)
        set(TKTABLE_${package}_CONFIG_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}")
      else ()
        string(TOLOWER "${package}" package_lower)
        get_filename_component(package_libdir "${${package}_LIBRARY}" DIRECTORY)
        file(STRINGS "${${package}_INCLUDE_PATH}/${package_lower}.h" package_version_define
          REGEX "^#define[ \t]+${package}_VERSION[ \t]+")
        if (NOT package_version_define MATCHES "[0-9]+\\.[0-9]+")
          message(FATAL_ERROR "Cannot determine ${package} version from ${${package}_INCLUDE_PATH}")
        endif ()
        set(package_version "${CMAKE_MATCH_0}")
        find_file(TKTABLE_${package}_CONFIG
          NAMES ${package_lower}Config.sh
          HINTS "${package_libdir}"
          PATH_SUFFIXES ${package_lower}${package_version}
          NO_DEFAULT_PATH NO_CACHE REQUIRED)
        get_filename_component(TKTABLE_${package}_CONFIG_DIR "${TKTABLE_${package}_CONFIG}" DIRECTORY)
      endif ()
    endforeach()
    configure_file(tktable_configure.cmake.in tktable_configure.cmake @ONLY)
    set(tktable_configure_command ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tktable_configure.cmake)
    set(tktable_build_command ${BEXT_MAKE_COMMAND} -j${pcnt} binaries)
    set(tktable_install_command ${BEXT_MAKE_COMMAND} -j1 INSTALL_OPTIONS=-C install-binaries install-libraries)
  endif ()

  ExternalProject_Add(TKTABLE_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/tktable"
    BINARY_DIR "${TKTABLE_BIN_DIR}"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${TKTABLE_PATCH_COMMAND}
    CONFIGURE_COMMAND ${tktable_configure_command}
    BUILD_COMMAND ${tktable_build_command}
    INSTALL_COMMAND ${tktable_install_command}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (NOT MSVC)
    ExternalProject_Add_StepDependencies(TKTABLE_BLD configure
      "${CMAKE_CURRENT_BINARY_DIR}/tktable_configure.cmake")
  endif ()

  TargetInstallDeps(TKTABLE TKTABLE_DEPENDS)

  set(tktable_test_dependencies TKTABLE_BLD)
  if (TARGET TCL_BLD)
    set(tktable_tclsh "${CMAKE_BUNDLE_INSTALL_PREFIX}/${BIN_DIR}/tclsh${CMAKE_EXECUTABLE_SUFFIX}")
    list(APPEND tktable_test_dependencies tclsh_cpy)
  else ()
    set(tktable_tclsh "${TCL_TCLSH}")
  endif ()
  set(tktable_test_command
    "${tktable_tclsh}" "${CMAKE_CURRENT_SOURCE_DIR}/run_tests.tcl"
    "${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}" "${TKTABLE_SRC_DIR}/tests")
  if (BEXT_XMIN_ROOT)
    find_program(TKTABLE_XMIN_RUN NAMES xmin-run HINTS "${BEXT_XMIN_ROOT}/bin" NO_DEFAULT_PATH NO_CACHE REQUIRED)
    find_program(TKTABLE_XMIN_SERVER NAMES Xmin HINTS "${BEXT_XMIN_ROOT}/bin" NO_DEFAULT_PATH NO_CACHE REQUIRED)
    set(tktable_test_screen "1280x960x24")
    list(PREPEND tktable_test_command
      "${CMAKE_COMMAND}" -E env --modify "LD_LIBRARY_PATH=path_list_prepend:${BEXT_XMIN_ROOT}/lib"
      "${TKTABLE_XMIN_RUN}" --server "${TKTABLE_XMIN_SERVER}" --screen "${tktable_test_screen}" --)
  endif ()
  add_custom_target(TKTABLE_check
    COMMAND ${tktable_test_command}
    DEPENDS ${tktable_test_dependencies}
    WORKING_DIRECTORY "${TKTABLE_BIN_DIR}"
    USES_TERMINAL
    VERBATIM)

  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/tktable/license.txt
    ${DOC_LICENSE_DIR}/tktable.txt
    COPYONLY
    )

endif (ENABLE_TKTABLE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
