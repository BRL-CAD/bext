# Decide if we're using stepcode
cad_enable(STEPCODE "conv")

bext_enable(STEPCODE)

# Decision made

if (ENABLE_STEPCODE)

  git_submodule_init(stepcode CMakeLists.txt)

  RegisterDeps(STEPCODE)

  # For OSX, we need CMAKE_INSTALL_NAME_DIR
  set(CMAKE_INSTALL_NAME_DIR "@rpath")

  # bext: stepcode declares many globals with SC_EXPRESS_EXPORT (which resolves
  # to __declspec(dllexport) under WIN32) but does not extern-declare them in
  # its own headers.  Under GCC 10+ (mingw's default -fno-common), each .c
  # that includes the header emits its own definition and the DLL export
  # decoration adds an extra leading underscore, producing exported symbols
  # like `__ALLOC_new` / `__EXPcreate` etc. -- yet ld looks for the
  # `__imp_ALLOC_new` etc. that __declspec(dllimport) generates in consumers.
  # Restore the pre-GCC-10 tentative-definition semantics via -fcommon so the
  # export decoration matches the import.  Gate on WIN32 GCC (MinGW-w64);
  # MSVC cl.exe / clang-cl / Linux/macOS untouched.
  set(STEPCODE_BEXT_C_FLAGS_INIT "")
  if (WIN32 AND CMAKE_C_COMPILER_ID STREQUAL "GNU")
    set(STEPCODE_BEXT_C_FLAGS_INIT "-fcommon")
  endif ()

  ExternalProject_Add(STEPCODE_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/stepcode"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${CMAKE_COMMAND};-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/stepcode;-DDEST_DIR=<SOURCE_DIR>;-P;${CMAKE_CURRENT_SOURCE_DIR}/RefreshSource.cmake
    COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/stepcode_string_pool.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DCMAKE_C_FLAGS_INIT=${STEPCODE_BEXT_C_FLAGS_INIT}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=OFF
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    -DCMAKE_INSTALL_NAME_DIR=${CMAKE_INSTALL_NAME_DIR}
    $<$<BOOL:${PERPLEX_TARGET}>:-DLEMON_ROOT=${CMAKE_NOBUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${PERPLEX_TARGET}>:-DPERPLEX_ROOT=${CMAKE_NOBUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${PERPLEX_TARGET}>:-DPERPLEX_TEMPLATE=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${DATA_DIR}/perplex/perplex_template.c>
    $<$<BOOL:${PERPLEX_TARGET}>:-DRE2C_ROOT=${CMAKE_NOBUNDLE_INSTALL_PREFIX}>
    -DSC_BUILD_SCHEMAS=
    -DSC_EXP2CXX_CHUNK_SIZE=64:8
    -DSC_ENABLE_COVERAGE=OFF
    -DSC_ENABLE_TESTING=OFF
    -DSC_IS_SUBBUILD=ON
    -DSC_PYTHON_GENERATOR=OFF
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(STEPCODE STEPCODE_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/stepcode/COPYING
    ${DOC_LICENSE_DIR}/stepcode.txt
    COPYONLY
    )

endif(ENABLE_STEPCODE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
