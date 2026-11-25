include("${CMAKE_CURRENT_LIST_DIR}/CMakeTestHelpers.cmake")
bext_test_reset("${TEST_ROOT}")
set(prefix "${TEST_ROOT}/prefix")
file(MAKE_DIRECTORY "${prefix}/install" "${prefix}/noinstall/bin")
if(WIN32)
  set(tool "noinstall/bin/bext_supply_chain.exe")
else()
  set(tool "noinstall/bin/bext_supply_chain")
endif()
file(WRITE "${prefix}/${tool}" "")
set(evidence_files
  bext-install-manifest.json bext-install-exclude-manifest.json bext-content-stamp
  bext.spdx.json bext.cdx.json bext-component-manifest.json
  bext-vex-evidence.json bext-vex-report.json bext.build.spdx.json
  bext.build.cdx.json bext.build.conan.spdx.json bext.build.conan.cdx.json
  bext.build.conan.spdx.coverage.json bext.build.conan.cdx.coverage.json)
foreach(name IN LISTS evidence_files)
  file(WRITE "${prefix}/${name}" "{}")
endforeach()
file(WRITE "${prefix}/bext-install-manifest.json" "{\"files\":[]}")
file(WRITE "${prefix}/bext.spdx.json"
  "{\"documentNamespace\":\"https://example.invalid/source\"}")
file(WRITE "${prefix}/bext-vex-evidence.json"
  "{\"sourceDocument\":\"https://example.invalid/source\",\"buildId\":\"fixture-build\"}")
set(archive "${TEST_ROOT}/dependencies.tar.gz")

function(package vex_generated expected_success)
  file(WRITE "${prefix}/bext-vex-report.json"
    "{\"vexGenerated\":${vex_generated},\"buildId\":\"fixture-build\"}")
  execute_process(COMMAND "${CMAKE_COMMAND}" "-DBEXT_PACKAGE_ROOT=${prefix}"
    "-DBEXT_PACKAGE_ARCHIVE=${archive}" -P "${SOURCE_ROOT}/CMake/PackageDependencies.cmake"
    RESULT_VARIABLE result ERROR_VARIABLE error)
  if(expected_success AND NOT result EQUAL 0)
    message(FATAL_ERROR "Dependency packaging failed: ${error}")
  elseif(NOT expected_success AND result EQUAL 0)
    message(FATAL_ERROR "Dependency packaging unexpectedly succeeded")
  endif()
  set(package_error "${error}" PARENT_SCOPE)
endfunction()

function(read_archive out)
  execute_process(COMMAND "${CMAKE_COMMAND}" -E tar tf "${archive}"
    OUTPUT_VARIABLE members COMMAND_ERROR_IS_FATAL ANY)
  string(REPLACE "\r\n" "\n" members "${members}")
  set(${out} "${members}" PARENT_SCOPE)
endfunction()

package(false TRUE)
read_archive(members)
foreach(name bext-vex-evidence.json bext.build.cdx.json bext-component-manifest.json
    bext.spdx.json bext.cdx.json bext-install-exclude-manifest.json bext-content-stamp)
  bext_test_require_contains("${members}" "${name}\n" "Dependency archive")
endforeach()
bext_test_require_not_contains("${members}" "bext.openvex.json" "Unreviewed dependency archive")

package(true FALSE)
if(EXISTS "${archive}")
  message(FATAL_ERROR "Failed VEX packaging left an archive")
endif()
file(WRITE "${prefix}/bext.openvex.json" "{}")
package(true TRUE)
file(REMOVE "${prefix}/bext-vex-evidence.json")
package(true FALSE)
if(EXISTS "${archive}")
  message(FATAL_ERROR "Missing evidence left an archive")
endif()
file(WRITE "${prefix}/bext-vex-evidence.json"
  "{\"sourceDocument\":\"https://example.invalid/source\",\"buildId\":\"fixture-build\"}")
file(REMOVE "${prefix}/bext.openvex.json")

package(false TRUE)
file(WRITE "${prefix}/bext.spdx.json"
  "{\"documentNamespace\":\"https://example.invalid/new-source\"}")
package(false FALSE)
bext_test_require_contains("${package_error}" "rerun bext_finalize" "Changed source inventory")
if(EXISTS "${archive}")
  message(FATAL_ERROR "Changed source inventory left an archive")
endif()

file(WRITE "${prefix}/bext.spdx.json"
  "{\"documentNamespace\":\"https://example.invalid/source\"}")
file(WRITE "${prefix}/install/owned" "owned")
file(WRITE "${prefix}/install/unrecorded" "unrecorded")
file(WRITE "${prefix}/bext-install-manifest.json" "{\"files\":[\"owned\"]}")
package(false TRUE)
read_archive(members)
bext_test_require_contains("${members}" "install/owned\n" "Recorded install output")
bext_test_require_not_contains("${members}" "install/unrecorded" "Unrecorded install output")
