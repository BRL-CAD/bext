# Unless we have ENABLE_ALL set, base the building of libregex on the system
# detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_REGEX)
  set(ENABLE_REGEX ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_REGEX)

if (NOT ENABLE_REGEX)

  find_package(REGEX)

  if (NOT REGEX_FOUND AND NOT DEFINED ENABLE_REGEX)
    set(ENABLE_REGEX "ON" CACHE BOOL "Enable regex build")
  endif (NOT REGEX_FOUND AND NOT DEFINED ENABLE_REGEX)

endif (NOT ENABLE_REGEX)
set(ENABLE_REGEX "${ENABLE_REGEX}" CACHE BOOL "Enable regex build")

if (ENABLE_REGEX)

  git_submodule_init(regex regex2.h)

  set(REGEX_DEPENDS PATCH)
  TargetVars(REGEX_DEPENDS)

  set(REGEX_PREFIX_STR "libregex_")

  # Platform differences in default linker behavior make it difficult to
  # guarantee that our libregex symbols will override libc. We'll avoid the
  # issue by renaming our libregex symbols to be incompatible with libc.
  ExternalProject_Add(REGEX_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/regex"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DREGEX_PREFIX_STR=${REGEX_PREFIX_STR}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(REGEX REGEX_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/regex/COPYRIGHT
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/regex.txt
    COPYONLY
    )

endif (ENABLE_REGEX)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

