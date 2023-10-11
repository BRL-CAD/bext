# Unless we have ENABLE_ALL set, based the building of tcl on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_QT)
  set(ENABLE_QT ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_QT)

if (NOT ENABLE_QT)

  find_package(Qt6 COMPONENTS Core Widgets Gui Svg OpenGL OpenGLWidgets Network)

  if (NOT Qt6Widgets_FOUND AND NOT DEFINED ENABLE_QT)
    set(ENABLE_QT "ON" CACHE BOOL "Enable Qt6 build")
  endif (NOT Qt6Widgets_FOUND AND NOT DEFINED ENABLE_QT)

endif (NOT ENABLE_QT)

set(ENABLE_QT "${ENABLE_QT}" CACHE BOOL "Enable Qt6 build")

if (ENABLE_QT)

  git_submodule_init(qt qtbase/configure)

  TargetDeps(Qt6)

  if (isMultiConfig)
    set(CBT $<CONFIG>)
  else (isMultiConfig)
    set(CBT ${CMAKE_BUILD_TYPE})
  endif (isMultiConfig)

  set(QT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/qt/qtbase")
  set(QT_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/qt6-build")
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qt_config.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/qt_config.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qt_build.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/qt_build.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qt_install.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/qt_install.cmake @ONLY)

  ExternalProject_Add(Qt6_BLD
    SOURCE_DIR "${QT_SOURCE_DIR}"
    BINARY_DIR "${QT_BUILD_DIR}"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/qt.patch
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${CBT} -P ${CMAKE_CURRENT_BINARY_DIR}/qt_config.cmake
    BUILD_COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${CBT} -P ${CMAKE_CURRENT_BINARY_DIR}/qt_build.cmake
    INSTALL_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/qt_install.cmake
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(Qt6 Qt6_DEPENDS)

  ExternalProject_Add(Qt6Svg_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/qt/qtsvg"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/qtsvg.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DQt6_DIR=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}/cmake/Qt6
    -DQt6_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  ExternalProject_Add_StepDependencies(Qt6Svg_BLD configure Qt6_BLD-install)

  # Copy the license info into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  execute_process(COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/qtbase)
  file(COPY qt/qtbase/LICENSES DESTINATION ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/)
  file(RENAME ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/LICENSES ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/qtbase)
  execute_process(COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/qtsvg)
  file(COPY qt/qtsvg/LICENSES DESTINATION ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/)
  file(RENAME ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/LICENSES ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/qtsvg)

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


