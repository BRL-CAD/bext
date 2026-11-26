include("${CMAKE_CURRENT_LIST_DIR}/CMakeTestHelpers.cmake")
bext_test_reset("${TEST_ROOT}")

function(run_package_policy_case name profile license_policy filter_large)
  set(root "${TEST_ROOT}/${name}")
  set(install "${root}/install")
  set(build "${root}/build")
  set(source "${root}/source")
  set(noinstall "${root}/noinstall")
  file(MAKE_DIRECTORY "${install}/man" "${build}/fixture" "${source}/CMake" "${noinstall}")
  foreach(filename runtime always license development build auxiliary test large-small)
    file(WRITE "${install}/man/${filename}" "${filename}")
  endforeach()
  string(REPEAT "x" 1048576 large_payload)
  file(WRITE "${install}/man/large-big" "${large_payload}")
  file(WRITE "${install}/man/stale" "stale")
  if(UNIX)
    file(CREATE_LINK "${install}/man/runtime" "${install}/man/runtime-link" SYMBOLIC)
  endif()

  set(installed_files)
  foreach(filename runtime always license development build auxiliary test large-small large-big)
    list(APPEND installed_files "${install}/man/${filename}")
  endforeach()
  if(UNIX)
    list(APPEND installed_files "${install}/man/runtime-link")
  endif()
  string(REPLACE ";" "\n" installed_text "${installed_files}")
  file(WRITE "${build}/fixture/install_manifest.txt" "${installed_text}\n")
  file(WRITE "${build}/active" "fixture\n")
  file(WRITE "${build}/ownership"
    "fixture|^man/(runtime(-link)?|always|license|development|build|auxiliary|test|large-.*)$\n")
  file(WRITE "${build}/selectors" "set(BEXT_SBOM_SELECTOR_IDS)\n")
  file(WRITE "${build}/sbom" "{}")
  file(WRITE "${source}/CMake/BextDependencyInventory.cmake" [=[
function(bext_collect_dependency_inventory)
endfunction()
function(bext_inventory_package_records out)
  set(${out} "" PARENT_SCOPE)
endfunction()
]=])
  file(WRITE "${build}/groups.cmake" [=[
set(BEXT_PACKAGE_GROUP_IDS always license development build auxiliary test large)
set(BEXT_PACKAGE_GROUP_always_NAME always_files)
set(BEXT_PACKAGE_GROUP_always_CATEGORY ALWAYS)
set(BEXT_PACKAGE_GROUP_always_PATTERNS "^man/always$")
set(BEXT_PACKAGE_GROUP_license_NAME restricted_files)
set(BEXT_PACKAGE_GROUP_license_CATEGORY LICENSE_RESTRICTED)
set(BEXT_PACKAGE_GROUP_license_PATTERNS "^man/license$")
set(BEXT_PACKAGE_GROUP_development_NAME development_files)
set(BEXT_PACKAGE_GROUP_development_CATEGORY DEVELOPMENT)
set(BEXT_PACKAGE_GROUP_development_PATTERNS "^man/development$")
set(BEXT_PACKAGE_GROUP_build_NAME build_tools)
set(BEXT_PACKAGE_GROUP_build_CATEGORY BUILD_TOOL)
set(BEXT_PACKAGE_GROUP_build_PATTERNS "^man/build$")
set(BEXT_PACKAGE_GROUP_auxiliary_NAME auxiliary_tools)
set(BEXT_PACKAGE_GROUP_auxiliary_CATEGORY AUXILIARY_TOOL)
set(BEXT_PACKAGE_GROUP_auxiliary_PATTERNS "^man/auxiliary$")
set(BEXT_PACKAGE_GROUP_test_NAME test_outputs)
set(BEXT_PACKAGE_GROUP_test_CATEGORY TEST)
set(BEXT_PACKAGE_GROUP_test_PATTERNS "^man/test$")
set(BEXT_PACKAGE_GROUP_large_NAME large_unused)
set(BEXT_PACKAGE_GROUP_large_CATEGORY LARGE_UNUSED)
set(BEXT_PACKAGE_GROUP_large_PATTERNS "^man/large-(small|big)$")
]=])

  execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DBEXT_INSTALL_ROOT=${install}"
    "-DBEXT_MANIFEST=${root}/manifest.json"
    "-DBEXT_INSTALL_EXCLUDE_MANIFEST=${root}/excluded.json"
    "-DBEXT_PACKAGE_GROUPS_FILE=${build}/groups.cmake"
    "-DBEXT_PACKAGE_PROFILE=${profile}"
    "-DBEXT_PACKAGE_LICENSE_POLICY=${license_policy}"
    "-DBEXT_PACKAGE_FILTER_LARGE_UNUSED=${filter_large}"
    -DBEXT_PACKAGE_LARGE_FILE_THRESHOLD_MB=1
    "-DBEXT_COMPONENT_MANIFEST=${root}/components.json"
    "-DBEXT_COMPONENT_OWNERSHIP_RULES=${build}/ownership"
    "-DBEXT_ACTIVE_COMPONENTS=${build}/active"
    "-DBEXT_SBOM_SELECTORS=${build}/selectors"
    "-DBEXT_SBOM=${build}/sbom"
    "-DBEXT_SOURCE_ROOT=${source}"
    "-DBEXT_BINARY_ROOT=${build}"
    "-DBEXT_NOINSTALL_ROOT=${noinstall}"
    "-DBEXT_FINGERPRINT=${FINGERPRINT}"
    "-DBEXT_OWNERSHIP=${OWNERSHIP}"
    -DBEXT_STRCLEAR=unused
    -DBEXT_SYSTEM_NAME=Linux -DBIN_DIR=bin -DLIB_DIR=lib
    -P "${SOURCE_ROOT}/CMake/FinalizeInstall.cmake"
    RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error)
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Package policy case ${name} failed: ${output}${error}")
  endif()

  file(READ "${root}/excluded.json" manifest)
  string(JSON schema GET "${manifest}" schema)
  string(JSON actual_profile GET "${manifest}" profile)
  if(NOT schema EQUAL 2 OR NOT actual_profile STREQUAL profile)
    message(FATAL_ERROR "Package policy metadata is invalid: ${manifest}")
  endif()
  string(JSON excluded_count LENGTH "${manifest}" files)
  set(actual)
  if(excluded_count GREATER 0)
    math(EXPR last "${excluded_count} - 1")
    foreach(index RANGE ${last})
      string(JSON path GET "${manifest}" files ${index})
      list(APPEND actual "${path}")
    endforeach()
  endif()
  list(SORT actual)
  set(expected ${ARGN})
  list(SORT expected)
  if(NOT actual STREQUAL expected)
    message(FATAL_ERROR
      "Package policy case ${name} excluded '${actual}', expected '${expected}'")
  endif()

  string(JSON retained_large_count LENGTH "${manifest}" large_retained_files)
  list(FIND actual man/large-big large_big_excluded)
  if(large_big_excluded EQUAL -1)
    if(NOT retained_large_count EQUAL 1)
      message(FATAL_ERROR "Case ${name} did not audit its retained large file")
    endif()
  elseif(NOT retained_large_count EQUAL 0)
    message(FATAL_ERROR "Case ${name} audited an excluded file as retained")
  endif()
endfunction()

run_package_policy_case(runtime RUNTIME REDISTRIBUTABLE ON
  man/always man/auxiliary man/build man/development man/large-big man/license
  man/stale man/test)
run_package_policy_case(sdk SDK REDISTRIBUTABLE ON
  man/always man/auxiliary man/license man/stale man/test)
run_package_policy_case(complete COMPLETE REDISTRIBUTABLE ON
  man/always man/license man/stale)
run_package_policy_case(unrestricted COMPLETE UNRESTRICTED ON
  man/always man/stale)
run_package_policy_case(filter-disabled RUNTIME REDISTRIBUTABLE OFF
  man/always man/auxiliary man/build man/development man/license man/stale man/test)
