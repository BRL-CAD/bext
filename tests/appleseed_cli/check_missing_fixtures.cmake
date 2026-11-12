execute_process(COMMAND "${CLI}" "--run-unit-${MODE}"
  RESULT_VARIABLE status OUTPUT_VARIABLE output ERROR_VARIABLE output)
if(NOT status STREQUAL "1")
  message(FATAL_ERROR "Expected exit status 1 for missing ${MODE} fixtures, got ${status}:\n${output}")
endif()
if(NOT output MATCHES "cannot run developer tests or benchmarks:")
  message(FATAL_ERROR "Missing actionable ${MODE} diagnostic:\n${output}")
endif()
