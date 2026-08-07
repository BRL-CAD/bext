
bext_enable(Boost)

if (ENABLE_BOOST)

  git_submodule_init(boost CMakeLists.txt)

  RegisterDeps(BOOST)

  if (TARGET ZLIB_BLD)
    set(Z_PREFIX_STR "brl_")
  endif (TARGET ZLIB_BLD)

  # bext (staged patch): Boost.Asio (pulled in by Boost.Cobalt, among others) calls
  # WSAStartup/WSACleanup, which live in the Winsock import libraries.  MSVC auto-links
  # these via `#pragma comment(lib, "ws2_32")`; GCC and Clang targeting MinGW ignore
  # that pragma, so the shared libs fail to link with undefined references to
  # `__imp_WSAStartup`/`__imp_WSACleanup`.  Append the winsock libs to
  # CMAKE_<LANG>_STANDARD_LIBRARIES -- emitted at the very end of every link line, the
  # only position where ld's left-to-right resolution actually pulls the import members
  # (linker *flags* precede the objects and would be dropped as unreferenced there).
  # Guarded by MSVC so clang-cl (MSVC ABI, honors the pragma) is left untouched, while
  # gcc/clang targeting MinGW get the libs.  Byte-identical across all three branches.
  if (NOT MSVC AND WIN32)
    set(BOOST_STD_LIBS "-lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 -lws2_32 -lmswsock")
    set(BOOST_STDLIB_ARGS
      "-DCMAKE_C_STANDARD_LIBRARIES=${BOOST_STD_LIBS}"
      "-DCMAKE_CXX_STANDARD_LIBRARIES=${BOOST_STD_LIBS}"
      )
  else (NOT MSVC AND WIN32)
    set(BOOST_STDLIB_ARGS)
  endif (NOT MSVC AND WIN32)

  ExternalProject_Add(BOOST_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/boost"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/boost_cmake.patch
    COMMAND ${CMAKE_COMMAND};-E;copy;${PROJECT_SOURCE_DIR}/CMake/FindZLIB.cmake;<SOURCE_DIR>/libs/iostreams/cmake/FindZLIB.cmake
    COMMAND ${CMAKE_COMMAND};-E;copy;${PROJECT_SOURCE_DIR}/boost/FindICU.cmake;<SOURCE_DIR>/libs/locale/cmake/FindICU.cmake
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX=ON>
    $<$<BOOL:${ZLIB_TARGET}>:-DZ_PREFIX_STR=${Z_PREFIX_STR}>
    -DZLIB_ROOT=$<$<BOOL:${ZLIB_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DICU_ROOT=$<$<BOOL:${ICU_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DZSTD_ROOT=$<$<BOOL:${ZSTD_TARGET}>:${CMAKE_BUNDLE_INSTALL_PREFIX}>
    -DBOOST_IOSTREAMS_ENABLE_BZIP2=OFF
    -DBOOST_IOSTREAMS_ENABLE_LZMA=OFF
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_SHARED_LIBS=ON
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    ${BOOST_STDLIB_ARGS}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(BOOST BOOST_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/boost/LICENSE_1_0.txt
    ${DOC_LICENSE_DIR}/boost.txt
    COPYONLY
    )

endif (ENABLE_BOOST)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
