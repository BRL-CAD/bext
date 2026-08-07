
bext_enable(OPENEXR)

if (ENABLE_OPENEXR)

  git_submodule_init(openexr CMakeLists.txt)

  RegisterDeps(OPENEXR)

  # bext (staged patch): on Windows, GNU ld disables its default "auto-export
  # every symbol" behaviour as soon as ANY symbol carries __declspec(dllexport)
  # -- which OpenEXR's IMF_EXPORT macro does.  OpenEXR's predefined attribute
  # types are explicitly instantiated in the library, so their out-of-line member
  # TypedAttribute<T>::value() is emitted as an ordinary (undecorated) external
  # symbol; ld then silently drops it from the DLL export table.  Downstream
  # consumers compiled at -O0 (our Debug build, where value() is NOT inlined at
  # the call site) fail to link with "undefined reference to
  # Imf::TypedAttribute<...>::value() const" (seen building OpenImageIO's exr
  # plugin).  MSVC's dllexport on the explicit instantiation exports these, so
  # MSVC is unaffected and is excluded here.
  #
  # CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS does NOT help: CMake refuses to synthesise a
  # .def when the target already carries __declspec markup, so it was silently
  # ignored (import lib kept only the ~2k dllexport'd symbols, value() absent).
  # Instead force ld's auto-export directly with --export-all-symbols, which on
  # PE/COFF exports every defined external symbol IN ADDITION to the dllexport'd
  # ones -- and does so regardless of GCC -fvisibility=hidden (OpenEXR sets
  # CXX_VISIBILITY_PRESET hidden), as verified empirically on this toolchain.
  # The full libOpenEXR external symbol table is ~16k, well under the 65535 PE
  # export cap.  Guarded to WIN32 AND NOT MSVC: --export-all-symbols is a
  # PE-only ld option (GNU ld rejects it on ELF/Linux) and is meaningless to
  # MSVC link.exe.  The OpenEXR native build does not touch
  # CMAKE_SHARED_LINKER_FLAGS (its -static Toolchain-mingw.cmake is a
  # cross-compile file we never pass), so this cache value is not clobbered.
  if (WIN32 AND NOT MSVC)
    set(OPENEXR_EXPORT_ARGS "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--export-all-symbols")
  else (WIN32 AND NOT MSVC)
    set(OPENEXR_EXPORT_ARGS)
  endif (WIN32 AND NOT MSVC)

  ExternalProject_Add(OPENEXR_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/openexr"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/openexr.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    ${OPENEXR_EXPORT_ARGS}
    -DOPENEXR_BUILD_TOOLS=OFF
    -DOPENEXR_BUILD_EXAMPLES=OFF
    # bext: we consume only the OpenEXR libraries, not its test suite.  On
    # MinGW/GCC the OpenEXRTest target fails to link with undefined references
    # to TypedAttribute<T>::value() const (a template-export mismatch in the
    # test sources), and the tests are never needed by BRL-CAD, so skip them.
    -DBUILD_TESTING=OFF
    # bext: force OpenEXR to build AND install its bundled Imath deterministically.
    # With the default (OFF), OpenEXR's find_package(Imath) can latch onto the
    # in-tree _deps/imath-build/config (a cached Imath_DIR defeats CMAKE_IGNORE_PATH),
    # taking the "use but don't install" path -- Imath is then linked but never
    # staged into the bundle, so a downstream find_package(OpenEXR) ->
    # find_dependency(Imath) fails (e.g. OpenColorIO).  Forcing internal skips
    # find_package so the install path (gated on OPENEXR_INSTALL=ON) always runs,
    # staging Imath's config into lib/cmake/Imath.  Compiler-agnostic.
    -DOPENEXR_FORCE_INTERNAL_IMATH=ON
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

  TargetInstallDeps(OPENEXR OPENEXR_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/openexr/LICENSE.md
    ${DOC_LICENSE_DIR}/openexr.txt
    COPYONLY
    )

endif (ENABLE_OPENEXR)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

