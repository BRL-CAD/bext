# Itk uses private Tcl and Itcl interfaces plus Tk stubs.  Build it only as
# part of bext's internally consistent Tcl/Tk stack; system Tcl/Tk must supply
# Itk.

if (USE_BRLCAD)

  cad_enable(ITK "${BEXT_TK_COMPONENTS}")

else (USE_BRLCAD)

  bext_enable_all_default(ITK itk)

endif (USE_BRLCAD)

if (TARGET TK_BLD AND NOT DEFINED ENABLE_ITK AND NOT DISABLE_ITK)
  set(ENABLE_ITK ON)
endif ()
set(ENABLE_ITK "${ENABLE_ITK}" CACHE BOOL "Enable itk build")

if (ENABLE_ITK)

  if (NOT TARGET TCL_BLD OR NOT TARGET TK_BLD)
    message(FATAL_ERROR
      "A local Itk build requires bext's bundled Tcl and Tk because Itk uses "
      "private Tcl and Itcl interfaces.  A system Tcl/Tk stack must provide "
      "Itk ${BEXT_ITK_MIN_VERSION} or newer; otherwise configure with "
      "-DENABLE_TCL=ON."
      )
  endif ()

  git_submodule_init(itk configure)

  RegisterDeps(ITK)

  set(BEXT_ITK_VERSION "${BEXT_ITK_BUNDLED_VERSION}" CACHE INTERNAL "Bundled Itk version" FORCE)
  set(RPATH_SUFFIX "itk${BEXT_ITK_BUNDLED_VERSION}")
  set(ITK_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/ITK_BLD-prefix/src/ITK_BLD")
  set(ITK_BIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/ITK_BLD-prefix/src/ITK_BLD-build")

  set(WITH_TCL_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}")
  set(WITH_TCL_INCLUDE_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/${INCLUDE_DIR}")
  set(TCL_SRC_DIR "${CMAKE_BINARY_DIR}/tcl/TCL_BLD-prefix/src/TCL_BLD")
  set(WITH_TK_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}")
  set(WITH_TK_INCLUDE_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/${INCLUDE_DIR}")
  set(TK_SRC_DIR "${CMAKE_BINARY_DIR}/tk/TK_BLD-prefix/src/TK_BLD")
  set(WITH_ITCL_DIR "${BEXT_ITCL_CONFIG_DIR}")
  set(ITCL_SRC_DIR "${BEXT_ITCL_SOURCE_DIR}")

  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/itk_configure.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/itk_configure.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/itk_build.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/itk_build.cmake @ONLY)
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/itk_install.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/itk_install.cmake @ONLY)

  if (NOT MSVC)
    ExternalProject_Add(ITK_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/itk"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${CMAKE_COMMAND} -DITK_SOURCE_DIR=<SOURCE_DIR> -DITK_PATCH_EXECUTABLE=${PATCH_NATIVE_EXECUTABLE} -DITK_PATCH_FILE=${CMAKE_CURRENT_SOURCE_DIR}/itk.patch -P ${CMAKE_CURRENT_SOURCE_DIR}/itk_apply_patch.cmake
      COMMAND ${CMAKE_COMMAND} -E make_directory <SOURCE_DIR>/tclconfig
      COMMAND ${CMAKE_COMMAND} -E copy ${BEXT_ITCL_BUNDLED_SOURCE_DIR}/tclconfig/install-sh <SOURCE_DIR>/tclconfig/install-sh
      CONFIGURE_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/itk_configure.cmake
      BUILD_COMMAND ${BEXT_MAKE_COMMAND} -j${pcnt}
      INSTALL_COMMAND ${BEXT_MAKE_COMMAND} -j1 install
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )
  else (NOT MSVC)
    ExternalProject_Add(ITK_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/itk"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${CMAKE_COMMAND} -DITK_SOURCE_DIR=<SOURCE_DIR> -DITK_PATCH_EXECUTABLE=${PATCH_NATIVE_EXECUTABLE} -DITK_PATCH_FILE=${CMAKE_CURRENT_SOURCE_DIR}/itk.patch -P ${CMAKE_CURRENT_SOURCE_DIR}/itk_apply_patch.cmake
      COMMAND ${CMAKE_COMMAND} -E make_directory <SOURCE_DIR>/tclconfig
      COMMAND ${CMAKE_COMMAND} -E copy ${BEXT_ITCL_BUNDLED_SOURCE_DIR}/tclconfig/install-sh <SOURCE_DIR>/tclconfig/install-sh
      CONFIGURE_COMMAND ""
      BINARY_DIR ${ITK_SRC_DIR}/win
      BUILD_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/itk_build.cmake
      INSTALL_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/itk_install.cmake
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )
  endif (NOT MSVC)

  TargetInstallDeps(ITK ITK_DEPENDS)

  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/itk/license.terms
    ${DOC_LICENSE_DIR}/itk.txt
    COPYONLY
    )

endif (ENABLE_ITK)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

