cmake_minimum_required(VERSION 3.19)

if (NOT DEFINED BEXT_PATCH_NATIVE_EXECUTABLE OR NOT BEXT_PATCH_NATIVE_EXECUTABLE)
  message(FATAL_ERROR "BEXT_PATCH_NATIVE_EXECUTABLE is not defined")
endif()

if (NOT DEFINED BEXT_PATCH_CHECK_OPTION OR NOT BEXT_PATCH_CHECK_OPTION)
  set(BEXT_PATCH_CHECK_OPTION "--dry-run")
endif()

set(patch_args)
set(seen_separator FALSE)
set(has_forward_flag FALSE)
set(has_reverse_flag FALSE)
set(has_noninteractive_flag FALSE)
set(has_check_flag FALSE)
set(has_input_file FALSE)
set(has_reject_file FALSE)
set(expect_input_file FALSE)
set(expect_reject_file FALSE)
set(input_file "")

math(EXPR last_arg "${CMAKE_ARGC} - 1")
foreach(arg_index RANGE 0 ${last_arg})
  set(arg "${CMAKE_ARGV${arg_index}}")
  if (seen_separator)
    # Some platform patch tools accept -p1 while others require -p 1.
    # Normalize the compact form once here for every wrapped invocation.
    if (arg MATCHES "^-p([0-9]+)$")
      list(APPEND patch_args "-p" "${CMAKE_MATCH_1}")
    else()
      list(APPEND patch_args "${arg}")
    endif()
    if (expect_input_file)
      set(input_file "${arg}")
      set(expect_input_file FALSE)
    elseif (expect_reject_file)
      set(expect_reject_file FALSE)
    elseif (arg STREQUAL "-i" OR arg STREQUAL "--input")
      set(has_input_file TRUE)
      set(expect_input_file TRUE)
    elseif (arg MATCHES "^-i(.+)")
      set(has_input_file TRUE)
      set(input_file "${CMAKE_MATCH_1}")
    elseif (arg MATCHES "^--input=(.+)")
      set(has_input_file TRUE)
      set(input_file "${CMAKE_MATCH_1}")
    endif()
    if (arg STREQUAL "-r" OR arg STREQUAL "--reject-file")
      set(has_reject_file TRUE)
      set(expect_reject_file TRUE)
    elseif (arg MATCHES "^-r(.+)")
      set(has_reject_file TRUE)
    elseif (arg MATCHES "^--reject-file=(.+)")
      set(has_reject_file TRUE)
    endif()
    if (arg STREQUAL "-N" OR arg STREQUAL "--forward")
      set(has_forward_flag TRUE)
    endif()
    if (arg STREQUAL "-R" OR arg STREQUAL "--reverse")
      set(has_reverse_flag TRUE)
    endif()
    if (arg STREQUAL "-f" OR arg STREQUAL "--force" OR
        arg STREQUAL "-t" OR arg STREQUAL "--batch")
      set(has_noninteractive_flag TRUE)
    endif()
    if (arg STREQUAL "-C" OR arg STREQUAL "--dry-run")
      set(has_check_flag TRUE)
    endif()
  endif()
  if (arg STREQUAL "--")
    set(seen_separator TRUE)
  endif()
endforeach()

if (NOT seen_separator)
  message(FATAL_ERROR "Patch wrapper requires '--' before patch arguments")
endif()

if (NOT patch_args)
  message(FATAL_ERROR "Patch wrapper did not receive any patch arguments")
endif()

if (expect_input_file)
  message(FATAL_ERROR "Patch input option is missing its file path")
endif()
if (expect_reject_file)
  message(FATAL_ERROR "Patch reject option is missing its file path")
endif()

set(reject_path "")
set(reject_log_path "")
if (input_file AND DEFINED BEXT_PATCH_REJECT_DIR AND
    BEXT_PATCH_REJECT_DIR)
  get_filename_component(patch_name "${input_file}" NAME)
  get_filename_component(patch_context "${CMAKE_CURRENT_BINARY_DIR}" NAME)
  string(REGEX REPLACE "[^A-Za-z0-9_.-]" "_" patch_context
    "${patch_context}")
  set(reject_path
    "${BEXT_PATCH_REJECT_DIR}/${patch_context}-${patch_name}.rej")
  set(reject_log_path "${reject_path}.log")
endif()

function(clear_reject_artifacts)
  if (reject_path)
    file(REMOVE "${reject_path}" "${reject_log_path}")
  endif()
endfunction()

function(preserve_reject_artifacts)
  if (NOT reject_path)
    return()
  endif()

  # Keep a native reject file when patch emitted one.  Applicability checks do
  # not normally emit rejects, so fall back to preserving the full patch.
  file(MAKE_DIRECTORY "${BEXT_PATCH_REJECT_DIR}")
  if (EXISTS "${reject_path}")
    file(SIZE "${reject_path}" reject_size)
  else()
    set(reject_size 0)
  endif()
  if (reject_size EQUAL 0)
    configure_file("${input_file}" "${reject_path}" COPYONLY)
  endif()
  file(WRITE "${reject_log_path}"
    "Patch file: ${input_file}\n"
    "Working directory: ${CMAKE_CURRENT_BINARY_DIR}\n\n"
    "${patch_failure_output}")
  message(STATUS
    "Saved failed patch and diagnostics to ${reject_path} and "
    "${reject_log_path}")
endfunction()

clear_reject_artifacts()
if (reject_path AND NOT has_reject_file)
  list(APPEND patch_args "-r" "${reject_path}")
endif()

# Patch commands run during configure/build steps cannot consult a user.  The
# short -t form is accepted by the bundled and supported Unix patch tools.
# Preserve an explicit --force/-f choice if a caller has made one.
if (NOT has_noninteractive_flag)
  list(PREPEND patch_args "-t")
endif()

# Preflight file-based patches so a bad patch cannot leave a source tree half
# modified.  Stdin cannot be preflighted because it cannot be replayed for the
# real invocation.
if (has_input_file AND NOT has_check_flag)
  set(forward_check_args ${patch_args})
  list(PREPEND forward_check_args "${BEXT_PATCH_CHECK_OPTION}")
  execute_process(
    COMMAND "${BEXT_PATCH_NATIVE_EXECUTABLE}" ${forward_check_args}
    RESULT_VARIABLE forward_check_result
    OUTPUT_VARIABLE forward_check_stdout
    ERROR_VARIABLE forward_check_stderr
  )

  if (NOT forward_check_result EQUAL 0)
    if (forward_check_result EQUAL 1 AND has_forward_flag AND
        NOT has_reverse_flag)
      set(reverse_check_args)
      foreach(arg IN LISTS patch_args)
        if (arg STREQUAL "-N" OR arg STREQUAL "--forward")
          continue()
        endif()
        list(APPEND reverse_check_args "${arg}")
      endforeach()
      list(PREPEND reverse_check_args "${BEXT_PATCH_CHECK_OPTION}" "-R")

      execute_process(
        COMMAND "${BEXT_PATCH_NATIVE_EXECUTABLE}" ${reverse_check_args}
        RESULT_VARIABLE reverse_result
        OUTPUT_QUIET
        ERROR_QUIET
      )

      if (reverse_result EQUAL 0)
        clear_reject_artifacts()
        message(STATUS
          "Patch already applied or reversed; continuing because -N/--forward was requested."
        )
        return()
      endif()
    endif()

    set(patch_failure_output
      "${forward_check_stdout}${forward_check_stderr}")
    preserve_reject_artifacts()
    if (forward_check_stdout)
      message("${forward_check_stdout}")
    endif()
    if (forward_check_stderr)
      message("${forward_check_stderr}")
    endif()
    message(FATAL_ERROR
      "Patch preflight failed with exit code ${forward_check_result}"
    )
  endif()
endif()

execute_process(
  COMMAND "${BEXT_PATCH_NATIVE_EXECUTABLE}" ${patch_args}
  RESULT_VARIABLE patch_result
  OUTPUT_VARIABLE patch_stdout
  ERROR_VARIABLE patch_stderr
  ECHO_OUTPUT_VARIABLE
  ECHO_ERROR_VARIABLE
)

if (patch_result EQUAL 0)
  clear_reject_artifacts()
  return()
endif()

if (patch_result EQUAL 1 AND has_forward_flag AND NOT has_reverse_flag)
  set(reverse_check_args)
  foreach(arg IN LISTS patch_args)
    if (arg STREQUAL "-N" OR arg STREQUAL "--forward")
      continue()
    endif()
    list(APPEND reverse_check_args "${arg}")
  endforeach()
  list(PREPEND reverse_check_args "${BEXT_PATCH_CHECK_OPTION}" "-R")

  execute_process(
    COMMAND "${BEXT_PATCH_NATIVE_EXECUTABLE}" ${reverse_check_args}
    RESULT_VARIABLE reverse_result
    OUTPUT_QUIET
    ERROR_QUIET
  )

  if (reverse_result EQUAL 0)
    clear_reject_artifacts()
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E echo
      "Patch already applied or reversed; continuing because -N/--forward was requested."
    )
    return()
  endif()
endif()

set(patch_failure_output "${patch_stdout}${patch_stderr}")
preserve_reject_artifacts()
message(FATAL_ERROR "Patch command failed with exit code ${patch_result}")
