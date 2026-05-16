if (NOT DEFINED PATCH_EXECUTABLE)
  message(FATAL_ERROR "PATCH_EXECUTABLE must be defined")
endif()

if (NOT DEFINED PATCH_WORKING_DIR)
  message(FATAL_ERROR "PATCH_WORKING_DIR must be defined")
endif()

if (NOT DEFINED PATCH_FILE)
  message(FATAL_ERROR "PATCH_FILE must be defined")
endif()

set(patch_cmd
  "${PATCH_EXECUTABLE}"
  -E
  -p1
  --ignore-whitespace
  -N
  --newline-output
  preserve
  -i
  "${PATCH_FILE}"
  )

execute_process(
  COMMAND ${patch_cmd} --dry-run
  WORKING_DIRECTORY "${PATCH_WORKING_DIR}"
  RESULT_VARIABLE patch_probe_result
  OUTPUT_VARIABLE patch_probe_stdout
  ERROR_VARIABLE patch_probe_stderr
)

if (patch_probe_result EQUAL 0)
  execute_process(
    COMMAND ${patch_cmd}
    WORKING_DIRECTORY "${PATCH_WORKING_DIR}"
    RESULT_VARIABLE patch_apply_result
  )
  if (NOT patch_apply_result EQUAL 0)
    message(FATAL_ERROR "Failed applying patch ${PATCH_FILE} in ${PATCH_WORKING_DIR}")
  endif()
  return()
endif()

set(patch_probe_text "${patch_probe_stdout}\n${patch_probe_stderr}")
if (patch_probe_text MATCHES "previously applied" OR patch_probe_text MATCHES "Reversed \\(or previously applied\\) patch detected")
  message(STATUS "Patch ${PATCH_FILE} already applied in ${PATCH_WORKING_DIR}; leaving source unchanged")
  return()
endif()

message(FATAL_ERROR "Patch probe failed for ${PATCH_FILE} in ${PATCH_WORKING_DIR}:\n${patch_probe_text}")
