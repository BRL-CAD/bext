
bext_enable(FMT)

if (ENABLE_FMT)

  git_submodule_init(fmt CMakeLists.txt)

  RegisterDeps(FMT)

  # bext: apply a single-hunk patch to fmt/include/fmt/ostream.h that skips the
  # MinGW __gnu_cxx::stdio_*_filebuf dynamic_cast branch when RTTI is disabled
  # in the including TU (__GXX_RTTI undefined).  Consumers such as OSL's
  # liboslexec compile llvm_util.cpp with -fno-rtti to match LLVM's ABI, and
  # under GCC/clang -fno-rtti forbids dynamic_cast even at parse time.  The
  # patch is safe on ALL platforms: MSVC takes its own branch (untouched);
  # Linux/macOS never reach the _WIN32 branches; MinGW RTTI-on TUs get the
  # same behavior as before (the added && defined(__GXX_RTTI) is true when
  # -frtti is in effect, which is GCC's default).
  ExternalProject_Add(FMT_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/fmt"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/fmt.patch
    CMAKE_ARGS
    -DFMT_DOC=OFF
    -DFMT_TEST=OFF
    ${BUILD_TYPE_SPECIFIER}
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

  TargetInstallDeps(FMT FMT_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/fmt/LICENSE
    ${DOC_LICENSE_DIR}/fmt.txt
    COPYONLY
    )

endif (ENABLE_FMT)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

