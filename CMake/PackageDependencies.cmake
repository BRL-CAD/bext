cmake_minimum_required(VERSION 3.26)

foreach(field BEXT_PACKAGE_ROOT BEXT_PACKAGE_ARCHIVE)
  if(NOT DEFINED ${field} OR "${${field}}" STREQUAL "")
    message(FATAL_ERROR "${field} is required")
  endif()
endforeach()

set(file_list "${BEXT_PACKAGE_ARCHIVE}.files")
file(REMOVE "${BEXT_PACKAGE_ARCHIVE}" "${BEXT_PACKAGE_ARCHIVE}.tmp" "${file_list}")
set(contents noinstall bext-install-manifest.json bext-install-exclude-manifest.json
  bext-component-manifest.json bext-content-stamp bext.spdx.json bext.cdx.json
  bext.build.spdx.json bext.build.cdx.json
  bext.build.conan.spdx.json bext.build.conan.cdx.json
  bext.build.conan.spdx.coverage.json bext.build.conan.cdx.coverage.json
  bext-vex-evidence.json bext-vex-report.json)
set(required ${contents} noinstall/share/bext/supply-chain/CMake/GenerateVex.py)
foreach(path IN LISTS required)
  if(NOT EXISTS "${BEXT_PACKAGE_ROOT}/${path}")
    message(FATAL_ERROR "Finalized release content is missing: ${path}")
  endif()
endforeach()
file(READ "${BEXT_PACKAGE_ROOT}/bext-vex-report.json" review_report)
file(READ "${BEXT_PACKAGE_ROOT}/bext-vex-evidence.json" evidence)
file(READ "${BEXT_PACKAGE_ROOT}/bext.spdx.json" source_inventory)
string(JSON source_namespace GET "${source_inventory}" documentNamespace)
string(JSON evidence_source GET "${evidence}" sourceDocument)
string(JSON evidence_build GET "${evidence}" buildId)
string(JSON report_build GET "${review_report}" buildId)
if(NOT source_namespace STREQUAL evidence_source OR NOT evidence_build STREQUAL report_build)
  message(FATAL_ERROR "Supply-chain companions describe different builds; rerun bext_finalize before packaging")
endif()
string(JSON vex_generated GET "${review_report}" vexGenerated)
if(vex_generated)
  if(NOT EXISTS "${BEXT_PACKAGE_ROOT}/bext.openvex.json")
    message(FATAL_ERROR "The reviewed build requires its OpenVEX document")
  endif()
  list(APPEND contents bext.openvex.json)
elseif(EXISTS "${BEXT_PACKAGE_ROOT}/bext.openvex.json")
  message(FATAL_ERROR "An unexpected OpenVEX document remains from another build")
endif()
file(READ "${BEXT_PACKAGE_ROOT}/bext-install-manifest.json" install_manifest)
string(JSON installed_count LENGTH "${install_manifest}" files)
# Native installers can leave unrecorded helpers in the prefix. Publish the
# finalized inventory rather than recursively adding that extra content.
if(installed_count GREATER 0)
  math(EXPR installed_last "${installed_count} - 1")
  foreach(index RANGE ${installed_last})
    string(JSON path GET "${install_manifest}" files ${index})
    if(IS_ABSOLUTE "${path}" OR "${path}" MATCHES "(^|/)\\.\\.(/|$)" OR
       NOT EXISTS "${BEXT_PACKAGE_ROOT}/install/${path}" OR IS_DIRECTORY "${BEXT_PACKAGE_ROOT}/install/${path}")
      message(FATAL_ERROR "Invalid or missing installed archive member: ${path}")
    endif()
    list(APPEND contents "install/${path}")
  endforeach()
endif()
string(REPLACE ";" "\n" archive_members "${contents}")
file(WRITE "${file_list}" "${archive_members}\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar cfz "${BEXT_PACKAGE_ARCHIVE}.tmp"
  --format=gnutar "--files-from=${file_list}"
  WORKING_DIRECTORY "${BEXT_PACKAGE_ROOT}" COMMAND_ERROR_IS_FATAL ANY)
file(REMOVE "${file_list}")
file(RENAME "${BEXT_PACKAGE_ARCHIVE}.tmp" "${BEXT_PACKAGE_ARCHIVE}")
