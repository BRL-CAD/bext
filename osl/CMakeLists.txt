
bext_enable(OSL)

if (ENABLE_OSL)

  set(OSL_PATCH_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/osl_environment_derivatives.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/osl_clang_diagnostic_lifetime.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/osl_bsdl_macros.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/osl_freebsd_obj_reader.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/osl_native_closure_callbacks.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/osl_atan2_derivatives.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/osl_public_header_exports.patch"
    "${CMAKE_CURRENT_SOURCE_DIR}/osl.patch"
    )
  if (MSVC AND CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|IntelLLVM)$")
    list(APPEND OSL_PATCH_FILES
      "${CMAKE_CURRENT_SOURCE_DIR}/osl_color_table_alignment.patch")
  endif ()
  git_submodule_init(OpenShadingLanguage CMakeLists.txt
    PATCH_FILES ${OSL_PATCH_FILES}
    INPUT_FILES
      "${PROJECT_SOURCE_DIR}/CMake/FindZLIB.cmake"
    PATCH_COMMAND_VAR OSL_PATCH_COMMAND)

  RegisterDeps(OSL)
  if (LLVM_TARGET)
    set(OSL_LLVM_ROOT "${CMAKE_BUNDLE_INSTALL_PREFIX}")
  else ()
    set(OSL_LLVM_ROOT "${LLVM_ROOT}")
  endif ()
  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)

  # winflexbison installs its binaries as win_flex.exe / win_bison.exe on
  # Windows; the portable names are plain flex / bison elsewhere.
  if (WIN32)
    set(OSL_FLEX_NAME win_flex.exe)
    set(OSL_BISON_NAME win_bison.exe)
  else ()
    set(OSL_FLEX_NAME flex)
    set(OSL_BISON_NAME bison)
  endif ()

  set(OSL_FLEXBISON_ARGS)
  if (BISON_TARGET)
    list(APPEND OSL_FLEXBISON_ARGS
      -DBISON_EXECUTABLE=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/${OSL_BISON_NAME}
      )
  endif (BISON_TARGET)
  if (FLEX_TARGET)
    list(APPEND OSL_FLEXBISON_ARGS
      -DFLEX_EXECUTABLE=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/${OSL_FLEX_NAME}
      )
  endif (FLEX_TARGET)

  set(OSL_MACOS_ARGS)
  if (APPLE)
    set(OSL_MACOS_SYSROOT "${CMAKE_OSX_SYSROOT}")
    if (NOT OSL_MACOS_SYSROOT)
      execute_process(
        COMMAND xcrun --sdk macosx --show-sdk-path
        OUTPUT_VARIABLE OSL_MACOS_SYSROOT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE OSL_MACOS_SDK_RESULT
      )
      if (NOT OSL_MACOS_SDK_RESULT STREQUAL "0" OR NOT IS_DIRECTORY "${OSL_MACOS_SYSROOT}")
        message(FATAL_ERROR "Unable to locate the macOS SDK required by OSL")
      endif ()
    endif ()
    list(APPEND OSL_MACOS_ARGS
      "-DCMAKE_OSX_SYSROOT=${OSL_MACOS_SYSROOT}"
      )
  endif ()

  ExternalProject_Add(OSL_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/OpenShadingLanguage"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${OSL_PATCH_COMMAND}
    COMMAND ${CMAKE_COMMAND};-E;copy;${PROJECT_SOURCE_DIR}/CMake/FindZLIB.cmake;<SOURCE_DIR>/src/cmake/modules/FindZLIB.cmake
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DImath_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_PREFIX_PATH=${CMAKE_BUNDLE_INSTALL_PREFIX}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DBISON_ROOT=$<$<BOOL:${BISON_TARGET}>:${CMAKE_NOBUNDLE_INSTALL_PREFIX}>
    -DFLEX_ROOT=$<$<BOOL:${FLEX_TARGET}>:${CMAKE_NOBUNDLE_INSTALL_PREFIX}>
    ${OSL_FLEXBISON_ARGS}
    ${OSL_MACOS_ARGS}
    -DLLVM_ROOT=${OSL_LLVM_ROOT}
    -DOPENEXR_ROOT=$<$<BOOL:${OPENEXR_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DOpenEXR_DIR=$<$<BOOL:${OPENEXR_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}/cmake/OpenEXR>
    -DOpenImageIO_ROOT=$<$<BOOL:${OPENIMAGEIO_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DPUGIXML_ROOT=$<$<BOOL:${PUGIXML_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DBUILD_MISSING_DEPS=OFF
    -DOSL_BUILD_TESTS=OFF
    -DOSL_BUILD_SHADERS=ON
    -DUSE_PYTHON=OFF
    -DUSE_QT=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
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

  TargetInstallDeps(OSL OSL_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/OpenShadingLanguage/LICENSE.md
    ${DOC_LICENSE_DIR}/openshadinglanguage.txt
    COPYONLY
    )

endif (ENABLE_OSL)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
