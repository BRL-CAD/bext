if (WIN32)
  # With winflexbison do all or nothing
  if (ENABLE_FLEX OR ENABLE_BISON)
    set(ENABLE_FLEX ON)
    set(ENABLE_BISON ON)
  endif (ENABLE_FLEX OR ENABLE_BISON)
endif (WIN32)

set(ENABLE_FLEX "${ENABLE_FLEX}" CACHE BOOL "Enable flex build")
set(ENABLE_BISON "${ENABLE_BISON}" CACHE BOOL "Enable GNU Bison build")

if (WIN32 AND ENABLE_FLEX)

  git_submodule_init(winflexbison CMakeLists.txt)

  set(FLEX_DEPENDS PATCH)
  TargetVars(FLEX_DEPENDS)

  # https://github.com/lexxmark/winflexbison
  ExternalProject_Add(FLEX_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/winflexbison"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/winflexbison.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(FLEX FLEX_DEPENDS)

endif (WIN32 AND ENABLE_FLEX)

if (NOT WIN32)
  if (ENABLE_FLEX)

    git_submodule_init(flex configure)

    set(FLEX_DEPENDS PATCH)
    TargetVars(FLEX_DEPENDS)

    set(FLEX_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/FLEX_BLD-prefix/src/FLEX_BLD")

    ExternalProject_Add(FLEX_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/flex"
      BUILD_IN_SOURCE ON
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/flex.patch
      CONFIGURE_COMMAND ${FLEX_SRC_DIR}/autogen.sh
      COMMAND ${FLEX_SRC_DIR}/configure --prefix=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
      BUILD_COMMAND ${BEXT_MAKE_COMMAND} -j${pcnt}
      INSTALL_COMMAND ${BEXT_MAKE_COMMAND} -j1 install
      DEPENDS ${ZLIB_TARGET}
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    TargetInstallDeps(FLEX FLEX_DEPENDS)

  endif (ENABLE_FLEX)
  if (ENABLE_BISON)

    git_submodule_init(bison configure)

    set(BISON_DEPENDS)
    TargetVars(BISON_DEPENDS)

    set(BISON_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/BISON_BLD-prefix/src/BISON_BLD")
    set(BISON_CONFIGURE_ENV MAKEINFO=true)
    if (APPLE)
      # macOS 26 declares posix_spawn_file_actions_addchdir, but the symbol is
      # unavailable when targeting older macOS releases.  Bison 3.8.2's older
      # gnulib consequently fails its link check and then redeclares the SDK
      # function with an incompatible replacement type.  The positive cache
      # result makes gnulib select its rpl_ wrapper around the available _np
      # function, avoiding both the new symbol and the conflicting declaration.
      list(APPEND BISON_CONFIGURE_ENV ac_cv_func_posix_spawn_file_actions_addchdir=yes)
    endif (APPLE)

    ExternalProject_Add(BISON_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/bison"
      BUILD_IN_SOURCE ON
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      # Preserve the shipped Autotools outputs when ExternalProject copies the
      # source tree.  This prevents make from requiring Autoconf, Autoheader,
      # or Automake from the host.
      CONFIGURE_COMMAND ${CMAKE_COMMAND};-E;touch_nocreate;${BISON_SRC_DIR}/configure;${BISON_SRC_DIR}/lib/config.in.h;${BISON_SRC_DIR}/Makefile.in
      # The release checkout includes generated Info documentation.  Do not
      # require host Texinfo when staging changes file timestamp ordering.
      COMMAND ${CMAKE_COMMAND} -E env ${BISON_CONFIGURE_ENV} ${BISON_SRC_DIR}/configure --prefix=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
      COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${BISON_SRC_DIR}/doc/bison.info
      BUILD_COMMAND ${BEXT_MAKE_COMMAND} -j${pcnt}
      INSTALL_COMMAND ${BEXT_MAKE_COMMAND} -j1 install
      DEPENDS ${ZLIB_TARGET}
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    TargetInstallDeps(BISON BISON_DEPENDS)

  endif (ENABLE_BISON)

endif (NOT WIN32)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
