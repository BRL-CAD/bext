# Patchelf is only useful on some platforms - don't worry about trying
# to build it everywhere
if (NOT MSVC AND NOT APPLE)

  # patchelf is used to rewrite RPATH settings on the third party binaries
  # after compilation - it is quite useful when it comes to making binary
  # bundles that can run successfully from locations other than their final
  # CMAKE_INSTALL_PREFIX target.

  if (ENABLE_ALL AND NOT DEFINED ENABLE_PATCHELF)
    set(ENABLE_PATCHELF ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_PATCHELF)

  if (NOT ENABLE_PATCHELF)

    find_program(PATCHELF_EXECUTABLE patchelf)
    mark_as_advanced(PATCHELF_EXECUTABLE)

    if (NOT PATCHELF_EXECUTABLE AND NOT DEFINED ENABLE_PATCHELF)
      set(ENABLE_PATCHELF "ON" CACHE BOOL "Enable patchelf build")
    endif (NOT PATCHELF_EXECUTABLE AND NOT DEFINED ENABLE_PATCHELF)

  endif (NOT ENABLE_PATCHELF)
  set(ENABLE_PATCHELF "${ENABLE_PATCHELF}" CACHE BOOL "Enable patchelf build")

  if (ENABLE_PATCHELF)

    ExternalProject_Add(PATCHELF_BLD
      SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/patchelf"
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      CMAKE_ARGS
      -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
      $<$<NOT:$<BOOL:${CMAKE_CONFIGURATION_TYPES}>>:-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}>
      -DBIN_DIR=${BIN_DIR}
      -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
      -DLIB_DIR=${LIB_DIR}
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

  endif (ENABLE_PATCHELF)

endif (NOT MSVC AND NOT APPLE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

