# Decide if we're using Qt6
cad_enable(QT "libqtcad")

set(QT_EXTRA_PATCHES "" CACHE STRING "Additional patches to apply to bundled Qt6")
list(PREPEND QT_EXTRA_PATCHES
  "${CMAKE_CURRENT_SOURCE_DIR}/qt_metadata.patch"
  "${CMAKE_CURRENT_SOURCE_DIR}/qt_freebsd.patch"
  "${CMAKE_CURRENT_SOURCE_DIR}/qt_CVE-2026-105924.patch")
list(REMOVE_DUPLICATES QT_EXTRA_PATCHES)
set(QT_XMIN_ROOT "" CACHE PATH "Installed Xmin SDK used by bundled Qt6")

if (BEXT_XMIN_ROOT AND NOT DISABLE_QT AND (NOT DEFINED ENABLE_QT OR ENABLE_QT))
  set(QT_XMIN_ROOT "${BEXT_XMIN_ROOT}")
  set(qt_xmin_patch "${CMAKE_CURRENT_SOURCE_DIR}/qt_xmin.patch")
  list(PREPEND QT_EXTRA_PATCHES "${qt_xmin_patch}")
  list(REMOVE_DUPLICATES QT_EXTRA_PATCHES)
endif ()

if (QT_XMIN_ROOT AND NOT DISABLE_QT AND (NOT DEFINED ENABLE_QT OR ENABLE_QT))
  set(ENABLE_QT "ON" CACHE BOOL "Enable Qt6 build" FORCE)
endif ()

if (NOT ENABLE_QT AND NOT DISABLE_QT)

  # Optional probe: a missing Qt6 just turns on the local build below, so pass
  # QUIET to avoid CMake's verbose "could not find Qt6 config file" warning.
  find_package(Qt6 QUIET COMPONENTS Core Widgets Gui Svg OpenGL OpenGLWidgets Network)

  if (NOT Qt6Widgets_FOUND AND NOT DEFINED ENABLE_QT)
    set(ENABLE_QT "ON" CACHE BOOL "Enable Qt6 build")
  endif (NOT Qt6Widgets_FOUND AND NOT DEFINED ENABLE_QT)

endif (NOT ENABLE_QT AND NOT DISABLE_QT)

set(ENABLE_QT "${ENABLE_QT}" CACHE BOOL "Enable Qt6 build")

# Decision made

if (ENABLE_QT)

  bext_component_ownership(qt
    "^bin/(androiddeployqt6|qmake6|qtpaths6|wasmdeployqt6|windeployqt6)([.]exe)?$"
    "^share/qt6/"
    "^sbom/(qtbase|qtsvg)-"
  )

  option(BEXT_QT_INSTALL_SDK_TOOLS "Include Qt SDK tools in downstream installations" OFF)
  if (NOT BEXT_QT_INSTALL_SDK_TOOLS)
    # Qt host and deployment tools are required while compiling consumers, but
    # are not part of the runtime payload published by those consumers.
    bext_install_exclude(
      "(^|/)(bin|libexec)/(androiddeployqt|androidtestrunner|cmake_automoc_parser|moc|qdbuscpp2xml|qdbusxml2cpp|qlalr|qmake|qtpaths|qvkgen|rcc|syncqt|tracegen|tracepointgen|uic|wasmdeployqt|windeployqt)6?([.]exe)?$"
      "(^|/)(bin|libexec)/(qt-cmake|qt-cmake-create|qt-cmake-private|qt-cmake-standalone-test|qt-configure-module|qt-internal-configure-examples|qt-internal-configure-tests)([.]bat)?$"
      "(^|/)(bin|libexec)/qt-cmake-private-install[.]cmake$"
      "(^|/)(bin|libexec)/(qt_cyclonedx_generator|qt-android-runner)[.]py$"
      "(^|/)(bin|libexec)/syncqt[.]pdb$"
    )
  endif (NOT BEXT_QT_INSTALL_SDK_TOOLS)

  option(QT_ALLOW_HEADLESS "Allow building Qt without a window-capable platform plugin" OFF)

  set(QT_XMIN_ENABLED OFF)
  set(QT_XMIN_DIR "")
  set(QT_XMIN_RUNTIME_DIRS "")
  set(QT_XMIN_CLIENT_DIR "")
  set(QT_XMIN_GL_DIR "")
  if (QT_XMIN_ROOT)
    if (NOT UNIX OR APPLE)
      message(FATAL_ERROR "The Xmin Qt profile currently requires Linux or BSD")
    endif ()
    if (NOT QT_EXTRA_PATCHES)
      message(FATAL_ERROR
        "QT_XMIN_ROOT requires the matching Xmin Qt patch in QT_EXTRA_PATCHES")
    endif ()

    if (NOT IS_DIRECTORY "${QT_XMIN_ROOT}")
      message(FATAL_ERROR "QT_XMIN_ROOT is not an installed SDK: ${QT_XMIN_ROOT}")
    endif ()
    file(REAL_PATH "${QT_XMIN_ROOT}" qt_xmin_root_real)
    set(QT_XMIN_ROOT "${qt_xmin_root_real}" CACHE PATH
      "Installed Xmin SDK used by bundled Qt6" FORCE)

    unset(Xmin_DIR CACHE)
    find_package(Xmin 0.1 CONFIG REQUIRED
      PATHS "${QT_XMIN_ROOT}"
      NO_DEFAULT_PATH
    )
    if (NOT TARGET Xmin::QtX11 OR NOT TARGET Xmin::GL OR
        NOT TARGET Xmin::ClientX11)
      message(FATAL_ERROR
        "QT_XMIN_ROOT must provide Xmin::QtX11, Xmin::GL, and Xmin::ClientX11")
    endif ()

    file(REAL_PATH "${Xmin_DIR}" qt_xmin_dir_real)
    cmake_path(IS_PREFIX qt_xmin_root_real "${qt_xmin_dir_real}"
      NORMALIZE qt_xmin_dir_in_root)
    if (NOT qt_xmin_dir_in_root)
      message(FATAL_ERROR
        "Xmin was resolved outside QT_XMIN_ROOT: ${qt_xmin_dir_real}")
    endif ()
    set(QT_XMIN_DIR "${qt_xmin_dir_real}")

    function(qt_xmin_imported_location target output_var)
      get_target_property(imported_configs "${target}" IMPORTED_CONFIGURATIONS)
      set(imported_location "")
      foreach(imported_config IN LISTS imported_configs)
        string(TOUPPER "${imported_config}" imported_config_upper)
        get_target_property(candidate "${target}"
          "IMPORTED_LOCATION_${imported_config_upper}")
        if (candidate AND EXISTS "${candidate}")
          set(imported_location "${candidate}")
          break()
        endif ()
      endforeach()
      if (NOT imported_location)
        get_target_property(imported_location "${target}" IMPORTED_LOCATION)
      endif ()
      if (NOT imported_location OR NOT EXISTS "${imported_location}")
        message(FATAL_ERROR "Unable to locate imported Xmin target ${target}")
      endif ()
      set(${output_var} "${imported_location}" PARENT_SCOPE)
    endfunction()

    qt_xmin_imported_location(Xmin::ClientX11 qt_xmin_client_library)
    qt_xmin_imported_location(Xmin::GL qt_xmin_gl_library)
    get_filename_component(QT_XMIN_CLIENT_DIR "${qt_xmin_client_library}" DIRECTORY)
    get_filename_component(QT_XMIN_GL_DIR "${qt_xmin_gl_library}" DIRECTORY)
    set(QT_XMIN_RUNTIME_DIRS "${QT_XMIN_GL_DIR};${QT_XMIN_CLIENT_DIR}")
    list(REMOVE_DUPLICATES QT_XMIN_RUNTIME_DIRS)
    set(QT_XMIN_ENABLED ON)
  endif ()

  RegisterDeps(Qt6)

  if (isMultiConfig)
    set(CBT $<CONFIG>)
  else (isMultiConfig)
    set(CBT ${CMAKE_BUILD_TYPE})
  endif (isMultiConfig)

  set(QT_UPSTREAM_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/qt/qtbase")
  set(QT_SOURCE_DIR "${QT_UPSTREAM_SOURCE_DIR}")
  set(QT_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/qt6-build")
  bext_sbom_selector(qt
    TARGET Qt6_BLD
    SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/SbomSelection.cmake"
    FUNCTION bext_qt_selected_packages
    CACHE "${QT_BUILD_DIR}/CMakeCache.txt"
    ARGUMENTS "${BEXT_QT_INSTALL_SDK_TOOLS}")
  # Qt rejects symlinks anywhere in its build path (e.g. /home on FreeBSD).
  # Create the directory first so REAL_PATH can resolve every component, then
  # use that physical path in ExternalProject and all Qt wrapper scripts.
  file(MAKE_DIRECTORY "${QT_BUILD_DIR}")
  file(REAL_PATH "${QT_BUILD_DIR}" QT_BUILD_DIR)
  set(qt_patch_hash_input "")
  foreach(QT_EXTRA_PATCH IN LISTS QT_EXTRA_PATCHES)
    if (NOT IS_ABSOLUTE "${QT_EXTRA_PATCH}")
      message(FATAL_ERROR "QT_EXTRA_PATCHES entries must be absolute paths: ${QT_EXTRA_PATCH}")
    endif ()
    if (NOT EXISTS "${QT_EXTRA_PATCH}")
      message(FATAL_ERROR "Additional Qt patch does not exist: ${QT_EXTRA_PATCH}")
    endif ()
    file(SHA256 "${QT_EXTRA_PATCH}" qt_patch_hash)
    string(APPEND qt_patch_hash_input "${QT_EXTRA_PATCH}:${qt_patch_hash}\n")
  endforeach()
  set(QT_TRACKED_PATCH_FILES
    ${QT_EXTRA_PATCHES}
    "${CMAKE_CURRENT_SOURCE_DIR}/qtsvg.patch")
  git_submodule_init(qt qtbase/configure
    PATCH_FILES ${QT_TRACKED_PATCH_FILES})
  bext_patch_command(QT_PATCH_COMMAND ${QT_EXTRA_PATCHES})
  bext_patch_command(QTSVG_PATCH_COMMAND
    "${CMAKE_CURRENT_SOURCE_DIR}/qtsvg.patch")
  string(SHA256 QT_PATCH_SIGNATURE "${qt_patch_hash_input}")

  # Make ExternalProject's configure rule sensitive to both the selected
  # profile and this wrapper script.  The script's own signature then clears
  # Qt's generated build tree before reconfiguring.
  file(SHA256 "${CMAKE_CURRENT_SOURCE_DIR}/qt_config.cmake.in"
    qt_config_template_hash)
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/qt_runtime.cmake")
  file(SHA256 "${CMAKE_CURRENT_SOURCE_DIR}/qt_runtime.cmake"
    qt_runtime_script_hash)
  string(SHA256 QT_CONFIG_SIGNATURE
    "${QT_PATCH_SIGNATURE}|${QT_XMIN_ENABLED}|${QT_XMIN_ROOT}|${QT_XMIN_DIR}|${qt_config_template_hash}|${qt_runtime_script_hash}|${CMAKE_BUILD_TYPE}")

  set(QT_SOURCE_ARGUMENTS SOURCE_DIR "${QT_SOURCE_DIR}")
  if (QT_EXTRA_PATCHES)
    string(SUBSTRING "${QT_PATCH_SIGNATURE}" 0 12 qt_patch_short_hash)
    set(QT_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/qt6-source-${qt_patch_short_hash}")
    set(QT_SOURCE_ARGUMENTS
      URL "${QT_UPSTREAM_SOURCE_DIR}"
      SOURCE_DIR "${QT_SOURCE_DIR}"
    )
  endif ()

  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qt_config.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/qt_config.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qt_build.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/qt_build.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qt_install.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/qt_install.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qt_xmin_audit.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/qt_xmin_audit.cmake @ONLY)

  set(QAH "OFF")
  if (QT_ALLOW_HEADLESS)
    set(QAH ${QT_ALLOW_HEADLESS})
  endif (QT_ALLOW_HEADLESS)

  ExternalProject_Add(Qt6_BLD
    ${QT_SOURCE_ARGUMENTS}
    BINARY_DIR "${QT_BUILD_DIR}"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${QT_PATCH_COMMAND}
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${CBT} -DQT_ALLOW_HEADLESS=${QAH} -DBEXT_QT_TARGET_SYSTEM_NAME=${CMAKE_SYSTEM_NAME} -DQT_CONFIG_SIGNATURE=${QT_CONFIG_SIGNATURE} -P ${CMAKE_CURRENT_BINARY_DIR}/qt_config.cmake
    BUILD_COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${CBT} -P ${CMAKE_CURRENT_BINARY_DIR}/qt_build.cmake
    INSTALL_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/qt_install.cmake
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(Qt6 Qt6_DEPENDS)

  set(QT_INSTALL_RPATH_DIRS "${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}")
  if (QT_XMIN_ENABLED)
    list(APPEND QT_INSTALL_RPATH_DIRS ${QT_XMIN_RUNTIME_DIRS})
  endif ()
  list(REMOVE_DUPLICATES QT_INSTALL_RPATH_DIRS)
  string(JOIN ":" QT_INSTALL_RPATH ${QT_INSTALL_RPATH_DIRS})

  set(QT_SVG_INSTALL_COMMAND)
  if (QT_XMIN_ENABLED)
    set(QT_SVG_INSTALL_COMMAND
      INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target install
      COMMAND ${CMAKE_COMMAND} -DQT_AUDIT_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}
        -DQT_AUDIT_INCLUDE_SVG=ON
        -P ${CMAKE_CURRENT_BINARY_DIR}/qt_xmin_audit.cmake
    )
  endif ()

  ExternalProject_Add(Qt6Svg_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/qt/qtsvg"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${QTSVG_PATCH_COMMAND}
    COMMAND ${CMAKE_COMMAND};-E;copy;${PROJECT_SOURCE_DIR}/CMake/FindZLIB.cmake;<SOURCE_DIR>/CMake/FindZLIB.cmake
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DQt6_DIR=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}/cmake/Qt6
    -DQt6_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DQT_BUILD_EXAMPLES=OFF
    -DQT_BUILD_TESTS=OFF
    -DFEATURE_developer_build=OFF
    $<$<BOOL:${QT_XMIN_ENABLED}>:-DXmin_DIR=${QT_XMIN_DIR}>
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${QT_INSTALL_RPATH}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    ${QT_SVG_INSTALL_COMMAND}
    STEP_TARGETS install
    )

  ExternalProject_Add_StepDependencies(Qt6Svg_BLD configure Qt6_BLD-install)

  # Copy the license info into position in CMAKE_BUNDLE_INSTALL_PREFIX
  execute_process(COMMAND ${CMAKE_COMMAND} -E rm -rf ${DOC_LICENSE_DIR}/qtbase)
  file(COPY qt/qtbase/LICENSES DESTINATION ${DOC_LICENSE_DIR}/)
  file(RENAME ${DOC_LICENSE_DIR}/LICENSES ${DOC_LICENSE_DIR}/qtbase)
  execute_process(COMMAND ${CMAKE_COMMAND} -E rm -rf ${DOC_LICENSE_DIR}/qtsvg)
  file(COPY qt/qtsvg/LICENSES DESTINATION ${DOC_LICENSE_DIR}/)
  file(RENAME ${DOC_LICENSE_DIR}/LICENSES ${DOC_LICENSE_DIR}/qtsvg)

endif (ENABLE_QT)

mark_as_advanced(Qt6_INCLUDE_DIRS)
mark_as_advanced(Qt6_LIBRARIES)
mark_as_advanced(Qt6_VERSION)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
