# This implementation of patch comes from https://github.com/shannonbooth/patch
# and supports most of the capabilities users of the standard Unix-type patch
# tools are familiar with.  We include it here to support applying patches
# during the build process even on platforms that don't normally supply this
# tool by default.
if (ENABLE_ALL AND NOT DEFINED ENABLE_PATCH)
  set(ENABLE_PATCH ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_PATCH)

# Although individual projects may need their own patching options, there are
# some common settings that will be used for most/all cases.  We define those
# here for uniformity.
#
# We ignore whitespace for portability and flexibility when applying patches
#
# -N avoids attempting to reverse patch if the patching is already done.
set(PATCH_OPTIONS "--ignore-whitespace;-N" CACHE STRING "Command line options to use when patching" FORCE)

if (NOT ENABLE_PATCH)

  find_program(PATCH_EXECUTABLE patch)
  mark_as_advanced(PATCH_EXECUTABLE)

  if (NOT PATCH_EXECUTABLE AND NOT DEFINED ENABLE_PATCH)
    set(ENABLE_PATCH "ON" CACHE BOOL "Enable patch build")
  endif (NOT PATCH_EXECUTABLE AND NOT DEFINED ENABLE_PATCH)

endif (NOT ENABLE_PATCH)
set(ENABLE_PATCH "${ENABLE_PATCH}" CACHE BOOL "Enable patch build")

if (ENABLE_PATCH)

  git_submodule_init(patch README.md)

  ExternalProject_Add(PATCH_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/patch"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
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

  set(PATCH_EXECUTABLE ${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/sb_patch${CMAKE_EXECUTABLE_SUFFIX} CACHE STRING "Patch executable" FORCE)
 
  # If we're using sb_patch, add the newline-output option
  set(PATCH_OPTIONS "${PATCH_OPTIONS};--newline-output;preserve" CACHE STRING "Command line options to use when patching" FORCE)

endif (ENABLE_PATCH)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

