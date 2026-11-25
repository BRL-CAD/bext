file(READ "${PLAN}" plan)
string(JSON build_root GET "${plan}" build_root)
string(JSON prefix GET "${plan}" prefix)
file(MAKE_DIRECTORY "${prefix}")
foreach(lock "${build_root}/bext-release.lock" "${prefix}/bext-release-prefix.lock")
  file(LOCK "${lock}" GUARD PROCESS TIMEOUT 0 RESULT_VARIABLE result)
  if (NOT result STREQUAL "0")
    message(FATAL_ERROR "Another build is using this build directory or install prefix: ${result}")
  endif ()
endforeach()
execute_process(
  COMMAND "${TOOL}" release-build --plan "${PLAN}"
  RESULT_VARIABLE result
  OUTPUT_VARIABLE driver_output
  ERROR_VARIABLE driver_error
  ECHO_OUTPUT_VARIABLE
  ECHO_ERROR_VARIABLE)
if (NOT result STREQUAL "0")
  message(FATAL_ERROR
    "Dependency build failed (${result}); see bext-release-logs for details\n${driver_error}")
endif ()
