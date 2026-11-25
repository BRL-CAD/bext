include("${CMAKE_CURRENT_LIST_DIR}/CMakeTestHelpers.cmake")
bext_test_reset("${TEST_ROOT}")
set(install "${TEST_ROOT}/install")
set(noinstall "${TEST_ROOT}/noinstall")
set(binary "${TEST_ROOT}/build")
file(MAKE_DIRECTORY "${install}/lib" "${noinstall}/bin"
  "${noinstall}/share/bext" "${noinstall}/share/doc/legal" "${binary}/tool")
file(WRITE "${install}/lib/owned" "install")
file(WRITE "${noinstall}/bin/helper" "helper")
if(WIN32)
  set(supply_chain_tool "bin/bext_supply_chain.exe")
else()
  set(supply_chain_tool "bin/bext_supply_chain")
endif()
file(WRITE "${noinstall}/${supply_chain_tool}" "tool")
file(WRITE "${noinstall}/share/bext/RefreshSpdx.cmake" "refresh")
file(WRITE "${noinstall}/share/doc/legal/bext-supply-chain-public-domain.txt" "public domain")
file(WRITE "${noinstall}/share/doc/legal/nlohmann-json.txt" "MIT")
file(WRITE "${noinstall}/build-stamp" "stamp")
file(WRITE "${noinstall}/stale" "stale")
file(WRITE "${binary}/tool/install_manifest.txt" "${noinstall}/bin/helper\n")
file(WRITE "${TEST_ROOT}/active.txt" "tool\n")
file(WRITE "${TEST_ROOT}/components.json"
  "{\"schema\":\"https://brlcad.org/schema/bext-component-manifest-v2\",\"platform\":\"fixture\",\"install_root\":\"install\",\"generated_by\":\"bext\",\"files\":[{\"path\":\"lib/owned\",\"component\":\"installed\"}],\"packages\":[{\"component\":\"installed\",\"id\":\"installed\",\"spdx_id\":\"SPDXRef-Package-installed\",\"primary\":true,\"output\":\"install\"}]}")

execute_process(COMMAND "${CMAKE_COMMAND}"
  "-DBEXT_INSTALL_ROOT=${install}" "-DBEXT_NOINSTALL_ROOT=${noinstall}"
  "-DBEXT_BINARY_ROOT=${binary}" "-DBEXT_ACTIVE_COMPONENTS=${TEST_ROOT}/active.txt"
  "-DBEXT_COMPONENT_MANIFEST=${TEST_ROOT}/components.json"
  "-DBEXT_NOINSTALL_MANIFEST=${TEST_ROOT}/noinstall.json"
  "-DBEXT_PACKAGE_COMPONENT_MANIFEST=${TEST_ROOT}/package.json"
  -DBEXT_SYSTEM_NAME=fixture -P "${SOURCE_ROOT}/CMake/FinalizePackage.cmake"
  COMMAND_ERROR_IS_FATAL ANY)

file(READ "${TEST_ROOT}/noinstall.json" noinstall_manifest)
file(READ "${TEST_ROOT}/package.json" package_manifest)
file(READ "${binary}/bext-untracked-noinstall-files.txt" untracked)
foreach(path "bin/helper" "${supply_chain_tool}" "share/doc/legal/nlohmann-json.txt")
  bext_test_require_contains("${noinstall_manifest}" "\"${path}\"" "Noinstall manifest")
endforeach()
bext_test_require_not_contains("${noinstall_manifest}" "stale" "Noinstall manifest")
string(JSON package_root GET "${package_manifest}" install_root)
if(NOT package_root STREQUAL ".")
  message(FATAL_ERROR "Package manifest has the wrong root: ${package_root}")
endif()
bext_test_require_contains("${package_manifest}" "SPDXRef-Package-nlohmann-json" "Package manifest")
bext_test_require_contains("${package_manifest}" "noinstall/bin/helper" "Package manifest")
bext_test_require_contains("${untracked}" "stale" "Untracked noinstall report")
