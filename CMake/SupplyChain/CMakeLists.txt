cmake_minimum_required(VERSION 3.26)
project(bext_supply_chain_tools LANGUAGES CXX)

include("${CMAKE_CURRENT_LIST_DIR}/../BextSupplyChain.cmake")
bext_add_supply_chain_tool()
add_executable(bext_supply_chain_fixture
  "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainToolFixture.cpp")
target_compile_features(bext_supply_chain_fixture PRIVATE cxx_std_17)

include(CTest)
if(BUILD_TESTING)
  add_executable(bext_process_tree_fixture
    "${CMAKE_CURRENT_LIST_DIR}/../tests/ProcessTreeFixture.cpp")
  target_compile_features(bext_process_tree_fixture PRIVATE cxx_std_17)

  add_executable(bext_fingerprint_fixture "${CMAKE_CURRENT_LIST_DIR}/../BextFingerprint.cpp")
  add_executable(bext_ownership_fixture "${CMAKE_CURRENT_LIST_DIR}/../BextOwnership.cpp")
  target_compile_features(bext_fingerprint_fixture PRIVATE cxx_std_17)
  target_compile_features(bext_ownership_fixture PRIVATE cxx_std_17)

  add_executable(bext_supply_chain_tests
    "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainFilesystemTests.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainGenerateTests.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainManifestTests.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainScannerTests.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainScanTests.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainTests.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/../tests/SupplyChainUpdateTests.cpp"
    Process.cpp)
  target_compile_features(bext_supply_chain_tests PRIVATE cxx_std_17)

  function(bext_add_supply_chain_test name label)
    add_test(NAME "supply-chain-${name}"
      COMMAND bext_supply_chain_tests
        --case "${name}"
        --tool "$<TARGET_FILE:bext_supply_chain>"
        --fixture "$<TARGET_FILE:bext_supply_chain_fixture>"
        --process-tree-fixture "$<TARGET_FILE:bext_process_tree_fixture>"
        --cmake "${CMAKE_COMMAND}"
        --source-root "${CMAKE_CURRENT_LIST_DIR}/../..")
    set_tests_properties("supply-chain-${name}" PROPERTIES LABELS "${label}")
  endfunction()

  function(bext_add_cmake_test name script)
    add_test(NAME "supply-chain-${name}"
      COMMAND "${CMAKE_COMMAND}"
        "-DSOURCE_ROOT=${CMAKE_CURRENT_LIST_DIR}/../.."
        "-DTEST_ROOT=${CMAKE_CURRENT_BINARY_DIR}/tests/${name}"
        "-DFINGERPRINT=$<TARGET_FILE:bext_fingerprint_fixture>"
        "-DOWNERSHIP=$<TARGET_FILE:bext_ownership_fixture>"
        -P "${CMAKE_CURRENT_LIST_DIR}/../tests/${script}")
    set_tests_properties("supply-chain-${name}" PROPERTIES LABELS "supply-chain-native")
  endfunction()

  foreach(name
      scan-coverage scan-github-case scan-stale-output scan-timeout
      updates-source-inputs updates-nonrelease-policy updates-group-selection
      updates-invalid-membership updates-committed-gitlink updates-online-candidates
      updates-tool-failure updates-failed-selection
      manifest-output-scopes manifest-invalid-output manifest-remapping
      filesystem-remove-retry filesystem-process-timeout-tree
      generate-directory-symlink generate-preserve-on-failure)
    bext_add_supply_chain_test("${name}" "supply-chain-native")
  endforeach()
  set_tests_properties(supply-chain-filesystem-process-timeout-tree PROPERTIES TIMEOUT 15)
  foreach(name scanner-grype scanner-trivy scanner-mixed-variants)
    bext_add_supply_chain_test("${name}" "supply-chain-scanner")
    set_tests_properties("supply-chain-${name}" PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 900)
  endforeach()
  bext_add_cmake_test(appleseed-stages TestAppleseedStages.cmake)
  bext_add_cmake_test(finalize-ownership TestFinalizeOwnership.cmake)
  bext_add_cmake_test(finalize-package TestFinalizePackage.cmake)
  bext_add_cmake_test(manpage-ownership TestManpageOwnership.cmake)
  bext_add_cmake_test(package-dependencies TestPackageDependencies.cmake)
  bext_add_cmake_test(spdx-refresh TestSpdxRefresh.cmake)

  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    enable_language(C)
    add_library(bext_plief_rpath_dependency SHARED
      "${CMAKE_CURRENT_LIST_DIR}/../tests/PliefRpathDependency.c")
    add_library(bext_plief_rpath_subject SHARED
      "${CMAKE_CURRENT_LIST_DIR}/../tests/PliefRpathSubject.c")
    target_link_libraries(bext_plief_rpath_subject PRIVATE bext_plief_rpath_dependency)
    add_executable(bext_plief_load_fixture
      "${CMAKE_CURRENT_LIST_DIR}/../tests/PliefLoadFixture.cpp")
    target_link_libraries(bext_plief_load_fixture PRIVATE "${CMAKE_DL_LIBS}")
    add_test(NAME supply-chain-plief-rpath
      COMMAND "${CMAKE_COMMAND}"
        "-DTEST_ROOT=${CMAKE_CURRENT_BINARY_DIR}/tests/plief-rpath"
        "-DDEPENDENCY=$<TARGET_FILE:bext_plief_rpath_dependency>"
        "-DSUBJECT=$<TARGET_FILE:bext_plief_rpath_subject>"
        "-DLOADER=$<TARGET_FILE:bext_plief_load_fixture>"
        -P "${CMAKE_CURRENT_LIST_DIR}/../tests/TestPliefRpath.cmake")
    set_tests_properties(supply-chain-plief-rpath PROPERTIES
      LABELS "supply-chain-native"
      SKIP_REGULAR_EXPRESSION "BEXT_TEST_PLIEF is not set")
  endif()
endif()
