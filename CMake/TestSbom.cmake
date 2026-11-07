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

set(dirty_probe "${BEXT_SOURCE_DIR}/sbom-dirty-provenance-test.tmp")
file(WRITE "${dirty_probe}" "first\n")
file(WRITE "${BEXT_SBOM_OUTPUT}" "stale\n")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_SBOM_OUTPUT=${BEXT_SBOM_OUTPUT}
    -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
  RESULT_VARIABLE refused_dirty_result
  ERROR_QUIET
)
if(refused_dirty_result EQUAL 0 OR EXISTS "${BEXT_SBOM_OUTPUT}")
  file(REMOVE "${dirty_probe}")
  message(FATAL_ERROR "Dirty SBOM generation did not reject and remove stale output")
endif()
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_SBOM_OUTPUT=${BEXT_SBOM_OUTPUT}
    -DBEXT_SBOM_ALLOW_DIRTY=ON
    -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
  RESULT_VARIABLE dirty_generation_result
)
file(READ "${BEXT_SBOM_OUTPUT}" first_dirty_sbom)
string(JSON first_dirty_namespace GET "${first_dirty_sbom}" documentNamespace)
file(WRITE "${dirty_probe}" "second\n")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_SBOM_OUTPUT=${BEXT_SBOM_OUTPUT}
    -DBEXT_SBOM_ALLOW_DIRTY=ON
    -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
  RESULT_VARIABLE changed_dirty_generation_result
)
file(READ "${BEXT_SBOM_OUTPUT}" second_dirty_sbom)
string(JSON second_dirty_namespace GET "${second_dirty_sbom}" documentNamespace)
file(REMOVE "${dirty_probe}")
if(NOT dirty_generation_result EQUAL 0 OR NOT changed_dirty_generation_result EQUAL 0)
  message(FATAL_ERROR "Dirty SBOM generation failed")
endif()
if(first_dirty_namespace STREQUAL second_dirty_namespace)
  message(FATAL_ERROR "Dirty source content did not change SBOM provenance")
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
