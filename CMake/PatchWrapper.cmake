cmake_minimum_required(VERSION 3.19)

if (NOT DEFINED BEXT_PATCH_NATIVE_EXECUTABLE OR NOT BEXT_PATCH_NATIVE_EXECUTABLE)
  message(FATAL_ERROR "BEXT_PATCH_NATIVE_EXECUTABLE is not defined")
endif()

set(patch_args)
set(seen_separator FALSE)
set(has_forward_flag FALSE)
set(has_reverse_flag FALSE)
set(has_noninteractive_flag FALSE)
set(has_dry_run_flag FALSE)
set(has_input_file FALSE)

math(EXPR last_arg "${CMAKE_ARGC} - 1")
foreach(arg_index RANGE 0 ${last_arg})
  set(arg "${CMAKE_ARGV${arg_index}}")
  if (seen_separator)
    list(APPEND patch_args "${arg}")
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
    if (arg STREQUAL "--dry-run")
      set(has_dry_run_flag TRUE)
    endif()
    if (arg STREQUAL "-i" OR arg STREQUAL "--input" OR
        arg MATCHES "^-i.+" OR arg MATCHES "^--input=.+")
      set(has_input_file TRUE)
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

# Patch commands run during configure/build steps cannot consult a user.  Both
# the bundled sb_patch and the Unix patch implementations we support accept
# --batch, which makes missing files and other patch problems fail instead of
# prompting indefinitely.  Preserve an explicit --force/-f choice if a caller
# has made one.
if (NOT has_noninteractive_flag)
  list(PREPEND patch_args "--batch")
endif()

# Preflight file-based patches so a bad patch cannot leave a source tree half
# modified.  Stdin cannot be preflighted because it cannot be replayed for the
# real invocation.
if (has_input_file AND NOT has_dry_run_flag)
  set(forward_dry_run_args ${patch_args})
  list(PREPEND forward_dry_run_args "--dry-run")
  execute_process(
    COMMAND "${BEXT_PATCH_NATIVE_EXECUTABLE}" ${forward_dry_run_args}
    RESULT_VARIABLE forward_dry_run_result
    OUTPUT_VARIABLE forward_dry_run_stdout
    ERROR_VARIABLE forward_dry_run_stderr
  )

  if (NOT forward_dry_run_result EQUAL 0)
    if (forward_dry_run_result EQUAL 1 AND has_forward_flag AND
        NOT has_reverse_flag)
      set(reverse_dry_run_args)
      foreach(arg IN LISTS patch_args)
        if (arg STREQUAL "-N" OR arg STREQUAL "--forward")
          continue()
        endif()
        list(APPEND reverse_dry_run_args "${arg}")
      endforeach()
      list(PREPEND reverse_dry_run_args "--dry-run" "-R")

      execute_process(
        COMMAND "${BEXT_PATCH_NATIVE_EXECUTABLE}" ${reverse_dry_run_args}
        RESULT_VARIABLE reverse_result
        OUTPUT_QUIET
        ERROR_QUIET
      )

      if (reverse_result EQUAL 0)
        message(STATUS
          "Patch already applied or reversed; continuing because -N/--forward was requested."
        )
        return()
      endif()
    endif()

    if (forward_dry_run_stdout)
      message("${forward_dry_run_stdout}")
    endif()
    if (forward_dry_run_stderr)
      message("${forward_dry_run_stderr}")
    endif()
    message(FATAL_ERROR
      "Patch preflight failed with exit code ${forward_dry_run_result}"
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
  return()
endif()

if (patch_result EQUAL 1 AND has_forward_flag AND NOT has_reverse_flag)
  set(reverse_dry_run_args)
  foreach(arg IN LISTS patch_args)
    if (arg STREQUAL "-N" OR arg STREQUAL "--forward")
      continue()
    endif()
    list(APPEND reverse_dry_run_args "${arg}")
  endforeach()
  list(PREPEND reverse_dry_run_args "--dry-run" "-R")

  execute_process(
    COMMAND "${BEXT_PATCH_NATIVE_EXECUTABLE}" ${reverse_dry_run_args}
    RESULT_VARIABLE reverse_result
    OUTPUT_QUIET
    ERROR_QUIET
  )

  if (reverse_result EQUAL 0)
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E echo
      "Patch already applied or reversed; continuing because -N/--forward was requested."
    )
    return()
  endif()
endif()

message(FATAL_ERROR "Patch command failed with exit code ${patch_result}")
