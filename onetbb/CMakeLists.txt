# Unless we have ENABLE_ALL set, based the building of oneTBB on
# the system detection results
bext_enable_all_default(ONETBB onetbb)

if (NOT ENABLE_ONETBB)

  # Optional probe: a missing TBB just turns on the local build below, so pass
  # QUIET to avoid CMake's verbose "could not find TBB config file" warning.
  find_package(TBB QUIET)

  if (NOT TBB_FOUND AND NOT DEFINED ENABLE_ONETBB)
    set(ENABLE_ONETBB "ON" CACHE BOOL "Enable oneTBB build")
  endif (NOT TBB_FOUND AND NOT DEFINED ENABLE_ONETBB)

endif (NOT ENABLE_ONETBB)
set(ENABLE_ONETBB "${ENABLE_ONETBB}" CACHE BOOL "Enable oneTBB build")

if (ENABLE_ONETBB)

  git_submodule_init(oneTBB CMakeLists.txt)

  RegisterDeps(ONETBB)

  # lld treats undefined symbols named by a version script as an error.  The
  # oneTBB scripts include optional Intel runtime symbols that are not emitted
  # by Clang builds, so retain the scripts while allowing those entries to be
  # absent.
  set(ONETBB_LINKER_ARGS)
  if (CMAKE_CXX_COMPILER_LINKER_ID STREQUAL "LLD" OR
      CMAKE_LINKER MATCHES "(^|/)ld\\.lld$")
    list(APPEND ONETBB_LINKER_ARGS
      -DCMAKE_SHARED_LINKER_FLAGS:STRING=-Wl,--undefined-version)
  endif ()

  ExternalProject_Add(ONETBB_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/oneTBB"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    # bext (staged patch): oneTBB's profiling.h declares the library-side
    # r1::itt_set_sync_name() taking "const tchar*", and tchar is unconditionally
    # wchar_t on all Windows (incl. MinGW).  The inline wrapper that converts a
    # char* name to wchar_t before calling it is gated on
    # "(_WIN32||_WIN64) && !__MINGW32__", so on MinGW that conversion is skipped
    # and the char* is passed straight to the wchar_t*-expecting r1 function ->
    # "cannot convert const char* to const wchar_t*" (fatal, building src/tbb).
    # The sibling create_itt_sync() already does the same char->wchar_t
    # conversion under a plain "(_WIN32||_WIN64)" guard and compiles fine on
    # MinGW, proving the conversion path works there.  The patch simply drops the
    # "&& !__MINGW32__" exclusion so MinGW uses the converting overloads like
    # MSVC.  No-op for MSVC (guard already true) and for non-Windows (guard
    # false), so it is safe to apply on every toolchain.
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/onetbb.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DTBB_TEST=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    ${ONETBB_LINKER_ARGS}
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

  TargetInstallDeps(ONETBB ONETBB_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/oneTBB/LICENSE.txt
    ${DOC_LICENSE_DIR}/oneTBB.txt
    COPYONLY
    )

endif (ENABLE_ONETBB)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
