cmake_minimum_required(VERSION 3.26)

if(NOT DEFINED BEXT_SOURCE_DIR)
  message(FATAL_ERROR "BEXT_SOURCE_DIR is required")
endif()
if(NOT DEFINED BEXT_REPORT_OUTPUT)
  message(FATAL_ERROR "BEXT_REPORT_OUTPUT is required")
endif()

include("${BEXT_SOURCE_DIR}/CMake/BextDependencyInventory.cmake")
bext_collect_dependency_inventory("${BEXT_SOURCE_DIR}")

get_filename_component(report_dir "${BEXT_REPORT_OUTPUT}" DIRECTORY)
file(MAKE_DIRECTORY "${report_dir}/CMakeFiles")

set(report "# Copyright notice candidates\n\n")
string(APPEND report "Generated from tracked source text. Every entry requires human review; this report never changes SBOM assertions automatically.\n\n")
get_property(metadata_sources GLOBAL PROPERTY BEXT_SBOM_METADATA_SOURCES)
foreach(source ${metadata_sources})
  bext_inventory_get(parent_source "${source}" SBOM_PARENT)
  if(parent_source)
    set(lookup_source "${parent_source}")
    bext_inventory_get(search_path "${source}" SBOM_COMPONENT)
  else()
    set(lookup_source "${source}")
    set(search_path ".")
  endif()
  if(NOT EXISTS "${BEXT_SOURCE_DIR}/${lookup_source}/.git")
    continue()
  endif()

  _bext_inventory_key(source_key "${source}")
  set(candidate_file "${report_dir}/CMakeFiles/${source_key}-copyright-candidates.txt")
  execute_process(
    COMMAND git grep -I -h -E "SPDX-FileCopyrightText:|[Cc]opyright[[:space:]]*(\\([cC]\\)|[0-9][0-9][0-9][0-9]|©)"
      -- "${search_path}"
    WORKING_DIRECTORY "${BEXT_SOURCE_DIR}/${lookup_source}"
    RESULT_VARIABLE grep_result
    OUTPUT_FILE "${candidate_file}"
    ERROR_VARIABLE grep_error
  )
  if(NOT grep_result EQUAL 0 AND NOT grep_result EQUAL 1)
    string(STRIP "${grep_error}" grep_error)
    message(FATAL_ERROR "Unable to inspect copyright notices in ${source}: ${grep_error}")
  endif()

  string(APPEND report "## `${source}`\n\n")
  file(STRINGS "${candidate_file}" candidates ENCODING UTF-8)
  file(REMOVE "${candidate_file}")
  if(candidates)
    list(REMOVE_DUPLICATES candidates)
    list(SORT candidates)
    foreach(candidate ${candidates})
      string(STRIP "${candidate}" candidate)
      if(candidate)
        string(APPEND report "    ${candidate}\n")
      endif()
    endforeach()
  else()
    string(APPEND report "No candidate notices found.\n")
  endif()
  string(APPEND report "\n")
endforeach()

file(WRITE "${BEXT_REPORT_OUTPUT}" "${report}")
message(STATUS "Wrote copyright notice candidates to ${BEXT_REPORT_OUTPUT}")
