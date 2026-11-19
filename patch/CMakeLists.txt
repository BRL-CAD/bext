# This implementation of patch comes from https://github.com/shannonbooth/patch
# and supports most of the capabilities users of the standard Unix-type patch
# tools are familiar with.  We include it here to support applying patches
# during the build process even on platforms that don't normally supply this
# tool by default.
bext_enable_all_default(PATCH patch)

function(bext_find_patch_check_option patch_executable result_variable)
  set(check_directory "${CMAKE_CURRENT_BINARY_DIR}/patch-option-check")
  set(check_input "${check_directory}/input.txt")
  set(check_patch "${check_directory}/change.patch")
  file(MAKE_DIRECTORY "${check_directory}")
  set(patch_text
    "--- input.txt\n+++ input.txt\n@@ -1,3 +1,3 @@\n first\n-before\n+after\n last\n")
  set(LF "\n")
  set(CRLF "\r\n")
  set(newlines LF)
  if (CMAKE_HOST_WIN32)
    # Git can check out our patches as CRLF while upstream files can use
    # either LF or CRLF, including in a single dependency.
    list(APPEND newlines CRLF)
  endif ()

  set(${result_variable} "" PARENT_SCOPE)
  foreach(check_option IN ITEMS "--dry-run" "-C")
    set(supported TRUE)
    foreach(patch_newline IN LISTS newlines)
      file(CONFIGURE OUTPUT "${check_patch}" CONTENT "${patch_text}"
        NEWLINE_STYLE ${patch_newline})
      foreach(input_newline IN LISTS newlines)
        # Ensure the dry run does not change even the file's line endings.
        file(CONFIGURE OUTPUT "${check_input}" CONTENT "first\nbefore\nlast\n"
          NEWLINE_STYLE ${input_newline})
        file(SHA256 "${check_input}" before)
        set(args -t ${PATCH_OPTIONS} -p 0 -i "${check_patch}")
        execute_process(
          COMMAND "${patch_executable}" "${check_option}" ${args}
          WORKING_DIRECTORY "${check_directory}"
          RESULT_VARIABLE status OUTPUT_QUIET ERROR_QUIET)
        if (NOT status STREQUAL "0" OR NOT EXISTS "${check_input}")
          set(supported FALSE)
          break()
        endif ()
        file(SHA256 "${check_input}" contents)
        if (NOT contents STREQUAL before)
          set(supported FALSE)
          break()
        endif ()
        execute_process(
          COMMAND "${patch_executable}" ${args}
          WORKING_DIRECTORY "${check_directory}"
          RESULT_VARIABLE status OUTPUT_QUIET ERROR_QUIET)
        if (NOT status STREQUAL "0" OR NOT EXISTS "${check_input}")
          set(supported FALSE)
          break()
        endif ()
        # The changed line may use the patch's newline. Keep the context
        # lines' original bytes so a partial edit cannot rewrite a file.
        set(eol "${${input_newline}}")
        string(SHA256 after "first${eol}after${eol}last${eol}")
        string(SHA256 after_patch_eol "first${eol}after${${patch_newline}}last${eol}")
        file(SHA256 "${check_input}" contents)
        if (NOT contents STREQUAL after AND NOT contents STREQUAL after_patch_eol)
          set(supported FALSE)
          break()
        endif ()
      endforeach ()
      if (NOT supported)
        break()
      endif ()
    endforeach ()
    if (supported)
      file(REMOVE_RECURSE "${check_directory}")
      set("${result_variable}" "${check_option}" PARENT_SCOPE)
      return()
    endif()
  endforeach()

  file(REMOVE_RECURSE "${check_directory}")
endfunction()

# Although individual projects may need their own patching options, there are
# some common settings that will be used for most/all cases.  We define those
# here for uniformity.
#
# We ignore whitespace for portability and flexibility when applying patches.
# Use split short options accepted by both bundled and Unix patch tools.
#
# -N avoids attempting to reverse patch if the patching is already done.
set(PATCH_OPTIONS -l -N)

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

  set(PATCH_CHECK_OPTION "")
  if (PATCH_NATIVE_EXECUTABLE)
    execute_process(COMMAND "${PATCH_NATIVE_EXECUTABLE}" --help
      OUTPUT_VARIABLE patch_help ERROR_VARIABLE patch_help)
    if (patch_help MATCHES "--newline-output")
      list(APPEND PATCH_OPTIONS --newline-output preserve)
    endif ()
    bext_find_patch_check_option("${PATCH_NATIVE_EXECUTABLE}" PATCH_CHECK_OPTION)
  endif ()
  if (NOT PATCH_CHECK_OPTION)
    if (DEFINED ENABLE_PATCH AND NOT ENABLE_PATCH STREQUAL "")
      message(FATAL_ERROR
        "ENABLE_PATCH is OFF, but no compatible system patch tool is available "
        "(found: ${PATCH_NATIVE_EXECUTABLE}). Enable the bundled patch tool "
        "or set PATCH_NATIVE_EXECUTABLE to a compatible executable.")
    endif ()
    if (PATCH_NATIVE_EXECUTABLE)
      message(STATUS "Patch tool ${PATCH_NATIVE_EXECUTABLE} failed the applicability and newline check. Building the bundled patch tool.")
    endif ()
    set(ENABLE_PATCH ON)
  endif ()

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
  set(PATCH_OPTIONS -l -N --newline-output preserve)
  set(PATCH_CHECK_OPTION "--dry-run")

endif (ENABLE_PATCH)

set(PATCH_OPTIONS "${PATCH_OPTIONS}" CACHE STRING "Command line options to use when patching" FORCE)
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
