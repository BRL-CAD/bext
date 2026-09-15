# This implementation of patch comes from https://github.com/shannonbooth/patch
# and supports most of the capabilities users of the standard Unix-type patch
# tools are familiar with.  We include it here to support applying patches
# during the build process even on platforms that don't normally supply this
# tool by default.
bext_enable_all_default(PATCH patch)

function(bext_find_patch_check_option patch_executable result_variable)
  set(check_directory "${CMAKE_BINARY_DIR}/CMakeFiles/patch-option-check")
  set(check_input "${check_directory}/input.txt")
  set(check_patch "${check_directory}/change.patch")
  file(MAKE_DIRECTORY "${check_directory}")
  file(WRITE "${check_patch}"
    "--- input.txt\n"
    "+++ input.txt\n"
    "@@ -1 +1 @@\n"
    "-before\n"
    "+after\n")

  foreach(check_option IN ITEMS "--dry-run" "-C")
    file(WRITE "${check_input}" "before\n")
    execute_process(
      COMMAND "${patch_executable}" "${check_option}" -t -p 0
        -i "${check_patch}"
      WORKING_DIRECTORY "${check_directory}"
      RESULT_VARIABLE check_result
      OUTPUT_QUIET
      ERROR_QUIET
    )
    file(READ "${check_input}" check_contents)
    if (check_result EQUAL 0 AND check_contents STREQUAL "before\n")
      file(REMOVE_RECURSE "${check_directory}")
      set("${result_variable}" "${check_option}" PARENT_SCOPE)
      return()
    endif()
  endforeach()

  file(REMOVE_RECURSE "${check_directory}")
  message(FATAL_ERROR
    "Patch executable ${patch_executable} has no supported check option")
endfunction()

# Although individual projects may need their own patching options, there are
# some common settings that will be used for most/all cases.  We define those
# here for uniformity.
#
# We ignore whitespace for portability and flexibility when applying patches.
# Use split short options accepted by both bundled and Unix patch tools.
#
# -N avoids attempting to reverse patch if the patching is already done.
set(PATCH_OPTIONS "-l;-N" CACHE STRING "Command line options to use when patching" FORCE)

# Preserve any existing user-specified patch path before we replace the public
# PATCH_EXECUTABLE variable with a wrapper command list.
if (DEFINED PATCH_EXECUTABLE AND NOT DEFINED PATCH_NATIVE_EXECUTABLE)
  set(PATCH_NATIVE_EXECUTABLE "${PATCH_EXECUTABLE}" CACHE FILEPATH "Underlying patch executable" FORCE)
endif (DEFINED PATCH_EXECUTABLE AND NOT DEFINED PATCH_NATIVE_EXECUTABLE)

if (NOT ENABLE_PATCH)

  if (NOT PATCH_NATIVE_EXECUTABLE)
    find_program(PATCH_NATIVE_EXECUTABLE patch)
  endif (NOT PATCH_NATIVE_EXECUTABLE)
  mark_as_advanced(PATCH_NATIVE_EXECUTABLE)

  if (NOT PATCH_NATIVE_EXECUTABLE AND NOT DEFINED ENABLE_PATCH)
    set(ENABLE_PATCH "ON" CACHE BOOL "Enable patch build")
  endif (NOT PATCH_NATIVE_EXECUTABLE AND NOT DEFINED ENABLE_PATCH)

endif (NOT ENABLE_PATCH)
set(ENABLE_PATCH "${ENABLE_PATCH}" CACHE BOOL "Enable patch build")

if (ENABLE_PATCH)

  git_submodule_init(patch README.md)

  ExternalProject_Add(PATCH_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/patch"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  set(PATCH_NATIVE_EXECUTABLE ${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${BIN_DIR}/sb_patch${CMAKE_EXECUTABLE_SUFFIX} CACHE FILEPATH "Underlying patch executable" FORCE)
 
  # If we're using sb_patch, add the newline-output option
  set(PATCH_OPTIONS "${PATCH_OPTIONS};--newline-output;preserve" CACHE STRING "Command line options to use when patching" FORCE)
  set(PATCH_CHECK_OPTION "--dry-run")

else (ENABLE_PATCH)

  # GNU and BSD patch use different options for an applicability check.
  bext_find_patch_check_option("${PATCH_NATIVE_EXECUTABLE}"
    PATCH_CHECK_OPTION)

endif (ENABLE_PATCH)

set(PATCH_CHECK_OPTION "${PATCH_CHECK_OPTION}" CACHE INTERNAL
  "Patch option for a non-modifying applicability check" FORCE)
set(PATCH_REJECT_DIR "${CMAKE_BINARY_DIR}/patch-rejects" CACHE INTERNAL
  "Directory for failed patch artifacts" FORCE)

set(PATCH_EXECUTABLE
  ${CMAKE_COMMAND}
  -DBEXT_PATCH_NATIVE_EXECUTABLE:FILEPATH=${PATCH_NATIVE_EXECUTABLE}
  -DBEXT_PATCH_CHECK_OPTION:STRING=${PATCH_CHECK_OPTION}
  -DBEXT_PATCH_REJECT_DIR:PATH=${PATCH_REJECT_DIR}
  -P
  ${CMAKE_SOURCE_DIR}/CMake/PatchWrapper.cmake
  --
  CACHE INTERNAL "Patch command wrapper" FORCE)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
