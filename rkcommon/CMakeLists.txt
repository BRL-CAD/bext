
bext_enable(RKCOMMON)

if (ENABLE_RKCOMMON)

  git_submodule_init(rkcommon CMakeLists.txt)

  RegisterDeps(RKCOMMON)

    # bext: rkcommon has two Windows non-MSVC portability bugs the parent bext
    # handles here so we don't touch the submodule.  Both are safe on all
    # toolchains (MSVC's behavior is unchanged), so apply unconditionally so
    # a stale patched-tree from a prior mixed run stays consistent.
    #  1. common.h aliases __PRETTY_FUNCTION__ to __FUNCSIG__ on any _WIN32 --
    #     __FUNCSIG__ is MSVC-only, so MinGW/clang-mingw fail with
    #     "'__FUNCSIG__' was not declared in this scope".  Tighten the guard
    #     to defined(_WIN32) && defined(_MSC_VER).
    #  2. rkcommon/rkcommon.rc is UTF-16LE with BOM; MSVC rc.exe accepts that,
    #     GNU windres does not.  Re-encode the file in place to UTF-8 on
    #     WIN32 non-MSVC (script is a no-op after the first pass).
    set(RKCOMMON_BEXT_PATCH_COMMAND
      ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/rkcommon.patch)
    if (WIN32 AND NOT MSVC)
      list(APPEND RKCOMMON_BEXT_PATCH_COMMAND
        COMMAND ${CMAKE_COMMAND} -DRC=<SOURCE_DIR>/rkcommon/rkcommon.rc -P ${CMAKE_CURRENT_SOURCE_DIR}/rkcommon_reencode_rc.cmake)
    endif ()

    # bext: on WIN32 non-MSVC, rkcommon's test suite (tests/) includes
    # math/test_box.cpp which uses M_PI/M_PI_2/M_1_PI without either defining
    # _USE_MATH_DEFINES or supplying its own constants -- MinGW's <cmath>
    # does not expose these unless the macro is set.  bext never runs the
    # rkcommon test suite, so disable BUILD_TESTING for this subproject on
    # GNU-Windows.  MSVC/Linux/macOS continue building the tests (unchanged).
    if (WIN32 AND NOT MSVC)
      set(RKCOMMON_BEXT_BUILD_TESTING OFF)
    else ()
      set(RKCOMMON_BEXT_BUILD_TESTING ON)
    endif ()

    # bext: rkcommon's cmake/rkcommon_redist_deps.cmake tries to install TBB
    # runtime DLLs alongside rkcommon on WIN32 (option INSTALL_DEPS, default
    # ON).  It searches for MSVC-style names 'tbb12_debug.dll' / 'tbb_debug.dll'
    # via find_file, which fails under MinGW/clang-mingw where our bext-built
    # TBB is named 'libtbb12_debug.dll' -- the install step then errors with
    # 'file INSTALL cannot find ...TBB_DLL_DEBUG-NOTFOUND'.  bext installs TBB
    # via its own ExternalProject with rpath handling, so rkcommon's DLL-copy
    # is redundant anyway.  Turn INSTALL_DEPS off on WIN32 non-MSVC only;
    # MSVC (which has the DLL naming rkcommon expects) is unchanged.
    if (WIN32 AND NOT MSVC)
      set(RKCOMMON_BEXT_INSTALL_DEPS OFF)
    else ()
      set(RKCOMMON_BEXT_INSTALL_DEPS ON)
    endif ()

    ExternalProject_Add(RKCOMMON_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/rkcommon"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${RKCOMMON_BEXT_PATCH_COMMAND}
    CMAKE_ARGS
    -DBUILD_TESTING=${RKCOMMON_BEXT_BUILD_TESTING}
    -DINSTALL_DEPS=${RKCOMMON_BEXT_INSTALL_DEPS}
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ONETBB_TARGET}>:-DRKCOMMON_TBB_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
    $<$<BOOL:${ONETBB_TARGET}>:-DTBB_ROOT=${CMAKE_BUNDLE_INSTALL_PREFIX}>
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

  TargetInstallDeps(RKCOMMON RKCOMMON_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/rkcommon/LICENSE.txt
    ${DOC_LICENSE_DIR}/rkcommon.txt
    COPYONLY
    )

endif (ENABLE_RKCOMMON)

# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
