include("${CMAKE_CURRENT_LIST_DIR}/CMakeTestHelpers.cmake")
bext_test_reset("${TEST_ROOT}")
set(install "${TEST_ROOT}/install")
set(build "${TEST_ROOT}/build")
set(source "${TEST_ROOT}/source")
set(noinstall "${TEST_ROOT}/noinstall")
file(MAKE_DIRECTORY "${install}/man" "${build}/native" "${source}/CMake" "${noinstall}")
foreach(name native override explicit stale)
  file(WRITE "${install}/man/${name}" "${name}")
endforeach()
file(WRITE "${build}/native/install_manifest.txt"
  "${install}/man/native\n${install}/man/override\n")
file(WRITE "${build}/active" "native\nowner\n")
file(WRITE "${build}/rules" "inactive|^man/.*\nowner|^man/(override|explicit)$\n")
file(WRITE "${build}/exclude" "")
file(WRITE "${build}/selectors" "set(BEXT_SBOM_SELECTOR_IDS)\n")
file(WRITE "${build}/sbom" "{}")
file(WRITE "${source}/CMake/BextDependencyInventory.cmake" [=[
function(bext_collect_dependency_inventory)
endfunction()
function(bext_inventory_package_records out)
  set(${out} "" PARENT_SCOPE)
endfunction()
]=])

execute_process(COMMAND "${CMAKE_COMMAND}"
  "-DBEXT_INSTALL_ROOT=${install}"
  "-DBEXT_MANIFEST=${TEST_ROOT}/manifest.json"
  "-DBEXT_INSTALL_EXCLUDE_MANIFEST=${TEST_ROOT}/excluded.json"
  "-DBEXT_COMPONENT_MANIFEST=${TEST_ROOT}/components.json"
  "-DBEXT_INSTALL_EXCLUDE_RULES=${build}/exclude"
  "-DBEXT_COMPONENT_OWNERSHIP_RULES=${build}/rules"
  "-DBEXT_ACTIVE_COMPONENTS=${build}/active"
  "-DBEXT_SBOM_SELECTORS=${build}/selectors"
  "-DBEXT_SBOM=${build}/sbom"
  "-DBEXT_SOURCE_ROOT=${source}"
  "-DBEXT_BINARY_ROOT=${build}"
  "-DBEXT_NOINSTALL_ROOT=${noinstall}"
  "-DBEXT_STRCLEAR=unused"
  "-DBEXT_FINGERPRINT=${FINGERPRINT}"
  "-DBEXT_OWNERSHIP=${OWNERSHIP}"
  -DBEXT_SYSTEM_NAME=Linux -DBIN_DIR=bin -DLIB_DIR=lib
  -P "${SOURCE_ROOT}/CMake/FinalizeInstall.cmake"
  RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error)
if(NOT result EQUAL 0)
  message(FATAL_ERROR "Install ownership finalization failed: ${output}${error}")
endif()

file(READ "${TEST_ROOT}/components.json" components)
string(JSON file_count LENGTH "${components}" files)
if(NOT file_count EQUAL 3)
  message(FATAL_ERROR "Expected three owned files, found ${file_count}")
endif()
set(actual)
math(EXPR last "${file_count} - 1")
foreach(index RANGE ${last})
  string(JSON path GET "${components}" files ${index} path)
  string(JSON component GET "${components}" files ${index} component)
  list(APPEND actual "${path}|${component}")
endforeach()
list(SORT actual)
set(expected "man/explicit|owner" "man/native|native" "man/override|owner")
if(NOT actual STREQUAL expected)
  message(FATAL_ERROR "Unexpected component ownership: ${actual}")
endif()
file(READ "${TEST_ROOT}/excluded.json" excluded)
string(JSON excluded_count LENGTH "${excluded}" files)
string(JSON excluded_path GET "${excluded}" files 0)
if(NOT excluded_count EQUAL 1 OR NOT excluded_path STREQUAL "man/stale")
  message(FATAL_ERROR "Unexpected excluded install files: ${excluded}")
endif()
