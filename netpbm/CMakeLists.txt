# Decide if we're using netpbm
cad_enable(NETPBM "libicv")

bext_enable(NETPBM)

# Decision made

if (ENABLE_NETPBM)

  git_submodule_init(netpbm CMakeLists.txt)

  RegisterDeps(NETPBM)

  # bext: netpbm compat gaps by compiler:
  # - Clang 20+ / clang-cl: lib/libpm.c calls getpid() without including
  #   <process.h> / <unistd.h>; -Wimplicit-function-declaration is a hard
  #   error per C99.  Silence with -Wno-implicit-function-declaration.
  # - GCC 15+ (mingw): lib/pmfileio.cxx re-declares mkstemp as `static`
  #   after mingw's stdlib.h has already declared it extern; GCC errors
  #   with "was declared 'extern' and later 'static' [-fpermissive]".
  #   Add -fpermissive to demote to warning (same behavior as GCC <15).
  # MSVC cl.exe accepts both patterns natively and is untouched.  Additive
  # via CMAKE_{C,CXX}_FLAGS_INIT so CMake's default flags are preserved.
  set(NETPBM_BEXT_C_FLAGS_INIT "")
  set(NETPBM_BEXT_CXX_FLAGS_INIT "")
  if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    if (MSVC)
      set(NETPBM_BEXT_C_FLAGS_INIT "/clang:-Wno-implicit-function-declaration")
    else ()
      set(NETPBM_BEXT_C_FLAGS_INIT "-Wno-implicit-function-declaration")
    endif ()
  endif ()
  if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(NETPBM_BEXT_CXX_FLAGS_INIT "-fpermissive")
  endif ()

  ExternalProject_Add(NETPBM_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/netpbm"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DCMAKE_C_FLAGS_INIT=${NETPBM_BEXT_C_FLAGS_INIT}
    -DCMAKE_CXX_FLAGS_INIT=${NETPBM_BEXT_CXX_FLAGS_INIT}
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

  TargetInstallDeps(NETPBM NETPBM_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE
    ${DOC_LICENSE_DIR}/netpbm.txt
    COPYONLY
    )

endif (ENABLE_NETPBM)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

