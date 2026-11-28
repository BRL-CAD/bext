cmake_minimum_required(VERSION 3.26)

foreach(field BEXT_PACKAGE_ROOT BEXT_PACKAGE_ARCHIVE)
  if(NOT DEFINED ${field} OR "${${field}}" STREQUAL "")
    message(FATAL_ERROR "${field} is required")
  endif()
endforeach()

set(file_list "${BEXT_PACKAGE_ARCHIVE}.files")
file(REMOVE "${BEXT_PACKAGE_ARCHIVE}" "${BEXT_PACKAGE_ARCHIVE}.tmp" "${file_list}")
set(contents bext-install-manifest.json bext-noinstall-manifest.json
  bext-install-exclude-manifest.json bext-component-manifest.json
  bext-package-component-manifest.json bext-content-stamp bext.spdx.json bext.cdx.json
  bext.build.spdx.json bext.build.cdx.json
  bext.build.conan.spdx.json bext.build.conan.cdx.json
  bext.build.conan.spdx.coverage.json bext.build.conan.cdx.coverage.json
  bext-vex-evidence.json bext-vex-report.json
  bext-package.build.spdx.json bext-package.build.cdx.json
  bext-package.build.conan.spdx.json bext-package.build.conan.cdx.json
  bext-package.build.conan.spdx.coverage.json bext-package.build.conan.cdx.coverage.json
  bext-package-vex-evidence.json bext-package-vex-report.json)
if(WIN32)
  set(supply_chain_tool noinstall/bin/bext_supply_chain.exe)
else()
  set(supply_chain_tool noinstall/bin/bext_supply_chain)
endif()
set(required ${contents} ${supply_chain_tool})
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
file(READ "${BEXT_PACKAGE_ROOT}/bext-package-vex-report.json" package_report)
file(READ "${BEXT_PACKAGE_ROOT}/bext-package-vex-evidence.json" package_evidence)
string(JSON package_source GET "${package_evidence}" sourceDocument)
string(JSON package_build GET "${package_evidence}" buildId)
string(JSON package_report_build GET "${package_report}" buildId)
if(NOT source_namespace STREQUAL package_source OR
    NOT package_build STREQUAL package_report_build)
  message(FATAL_ERROR "Package supply-chain companions describe different builds; rerun bext_finalize before packaging")
endif()
string(JSON package_vex_generated GET "${package_report}" vexGenerated)
if(package_vex_generated)
  message(FATAL_ERROR "The archive product inventory unexpectedly generated VEX")
elseif(EXISTS "${BEXT_PACKAGE_ROOT}/bext-package.openvex.json")
  message(FATAL_ERROR "An unexpected package OpenVEX document remains from another build")
endif()
# Native installers can leave unrecorded helpers in the prefix. Publish the
# finalized inventory rather than recursively adding that extra content.
foreach(tree install noinstall)
  file(READ "${BEXT_PACKAGE_ROOT}/bext-${tree}-manifest.json" manifest)
  string(JSON count LENGTH "${manifest}" files)
  if(count EQUAL 0)
    continue()
  endif()
  math(EXPR last "${count} - 1")
  foreach(index RANGE ${last})
    string(JSON path GET "${manifest}" files ${index})
    set(member "${BEXT_PACKAGE_ROOT}/${tree}/${path}")
    # Framework directory symlinks are individual archive members. Ordinary
    # directories would recursively pull in content outside the inventory.
    if(IS_ABSOLUTE "${path}" OR "${path}" MATCHES "(^|/)[.][.](/|$)" OR
       NOT EXISTS "${member}" OR (IS_DIRECTORY "${member}" AND NOT IS_SYMLINK "${member}"))
      message(FATAL_ERROR "Invalid or missing ${tree} archive member: ${path}")
    endif()
    list(APPEND contents "${tree}/${path}")
  endforeach()
endforeach()
list(REMOVE_DUPLICATES contents)
string(REPLACE ";" "\n" archive_members "${contents}")
file(WRITE "${file_list}" "${archive_members}\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar cfz "${BEXT_PACKAGE_ARCHIVE}.tmp"
  --format=gnutar "--files-from=${file_list}"
  WORKING_DIRECTORY "${BEXT_PACKAGE_ROOT}" COMMAND_ERROR_IS_FATAL ANY)
file(REMOVE "${file_list}")
file(RENAME "${BEXT_PACKAGE_ARCHIVE}.tmp" "${BEXT_PACKAGE_ARCHIVE}")
