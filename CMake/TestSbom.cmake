cmake_minimum_required(VERSION 3.26)

if(NOT DEFINED BEXT_SOURCE_DIR OR NOT DEFINED BEXT_SBOM_OUTPUT)
  message(FATAL_ERROR "BEXT_SOURCE_DIR and BEXT_SBOM_OUTPUT are required")
endif()

set(first "${BEXT_SBOM_OUTPUT}.first")
foreach(output "${first}" "${BEXT_SBOM_OUTPUT}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}"
      -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
      -DBEXT_SBOM_OUTPUT=${output}
      -DBEXT_SBOM_ALLOW_DIRTY=ON
      -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
    RESULT_VARIABLE generation_result
  )
  if(NOT generation_result EQUAL 0)
    message(FATAL_ERROR "SBOM generation failed")
  endif()
endforeach()
file(SHA256 "${first}" first_hash)
file(SHA256 "${BEXT_SBOM_OUTPUT}" second_hash)
file(REMOVE "${first}")
if(NOT first_hash STREQUAL second_hash)
  message(FATAL_ERROR "SBOM generation is not reproducible")
endif()

# Keep test mutations and outputs separate from the inventory published above.
while(TRUE)
  string(RANDOM LENGTH 24 ALPHABET 0123456789abcdef probe_id)
  set(dirty_probe "${BEXT_SOURCE_DIR}/sbom-dirty-provenance-${probe_id}.tmp")
  set(dirty_output "${BEXT_SBOM_OUTPUT}.dirty-${probe_id}")
  if(NOT EXISTS "${dirty_probe}" AND NOT EXISTS "${dirty_output}")
    break()
  endif()
endwhile()
file(WRITE "${dirty_probe}" "first\n")
file(WRITE "${dirty_output}" "stale\n")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_SBOM_OUTPUT=${dirty_output}
    -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
  RESULT_VARIABLE refused_dirty_result
  ERROR_QUIET
)
set(dirty_test_error "")
if(refused_dirty_result EQUAL 0 OR EXISTS "${dirty_output}")
  set(dirty_test_error "Dirty SBOM generation did not reject and remove stale output")
else()
  foreach(content first second)
    file(WRITE "${dirty_probe}" "${content}\n")
    execute_process(
      COMMAND "${CMAKE_COMMAND}"
        -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
        -DBEXT_SBOM_OUTPUT=${dirty_output}
        -DBEXT_SBOM_ALLOW_DIRTY=ON
        -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
      RESULT_VARIABLE dirty_generation_result
    )
    if(NOT dirty_generation_result EQUAL 0 OR NOT EXISTS "${dirty_output}")
      set(dirty_test_error "Dirty SBOM generation failed")
      break()
    endif()
    file(READ "${dirty_output}" dirty_sbom)
    string(JSON ${content}_dirty_namespace ERROR_VARIABLE json_error GET "${dirty_sbom}" documentNamespace)
    if(NOT json_error STREQUAL "NOTFOUND")
      set(dirty_test_error "Dirty SBOM has no document namespace: ${json_error}")
      break()
    endif()
  endforeach()
  if(NOT dirty_test_error AND first_dirty_namespace STREQUAL second_dirty_namespace)
    set(dirty_test_error "Dirty source content did not change SBOM provenance")
  endif()
endif()
file(REMOVE "${dirty_probe}" "${dirty_output}" "${dirty_output}.tmp")
if(dirty_test_error)
  message(FATAL_ERROR "${dirty_test_error}")
endif()

set(BEXT_SBOM_INPUT "${BEXT_SBOM_OUTPUT}")
include("${BEXT_SOURCE_DIR}/CMake/ValidateSbom.cmake")
file(READ "${BEXT_SBOM_OUTPUT}" sbom)
include("${BEXT_SOURCE_DIR}/CMake/SbomTestHelpers.cmake")
file(GLOB dependency_tests "${BEXT_SOURCE_DIR}/*/tests/Sbom.cmake")
if(NOT dependency_tests)
  message(FATAL_ERROR "No dependency-local SBOM regression checks were found")
endif()
foreach(test_script IN LISTS dependency_tests)
  get_filename_component(test_dir "${test_script}" DIRECTORY)
  get_filename_component(wrapper_dir "${test_dir}" DIRECTORY)
  get_filename_component(component "${wrapper_dir}" NAME)
  string(MAKE_C_IDENTIFIER "${component}" component)
  include("${test_script}")
  cmake_language(CALL "bext_test_${component}_sbom" "${sbom}")
endforeach()

set(metadata_report "${BEXT_SBOM_OUTPUT}.metadata.md")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_REPORT_OUTPUT=${metadata_report}
    -P ${BEXT_SOURCE_DIR}/CMake/ReportSbomMetadata.cmake
  RESULT_VARIABLE metadata_report_result
)
if(NOT metadata_report_result EQUAL 0)
  message(FATAL_ERROR "SBOM metadata report generation failed")
endif()
file(READ "${metadata_report}" metadata_report_text)
file(REMOVE "${metadata_report}")
foreach(required_heading
    "PURL review queue"
    "Declared license review queue"
    "Concluded license review queue"
    "Copyright review queue"
    "Upstream location review queue"
    "CPE review queue")
  if(NOT metadata_report_text MATCHES "## ${required_heading}")
    message(FATAL_ERROR "SBOM metadata report omitted ${required_heading}")
  endif()
endforeach()
if(BEXT_CYCLONEDX_OUTPUT)
  include("${CMAKE_CURRENT_LIST_DIR}/BextCycloneDx.cmake")
  file(READ "${BEXT_SBOM_OUTPUT}" final_inventory)
  bext_write_cyclonedx("${BEXT_CYCLONEDX_OUTPUT}" "${final_inventory}")
endif()
