cmake_minimum_required(VERSION 3.19)

if (NOT DEFINED BEXT_PATCH_NATIVE_EXECUTABLE OR NOT BEXT_PATCH_NATIVE_EXECUTABLE)
  message(FATAL_ERROR "BEXT_PATCH_NATIVE_EXECUTABLE is not defined")
endif()

set(patch_args)
set(seen_separator FALSE)
set(has_forward_flag FALSE)
set(has_reverse_flag FALSE)

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
