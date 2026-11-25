include("${CMAKE_CURRENT_LIST_DIR}/CMakeTestHelpers.cmake")
bext_test_reset("${TEST_ROOT}")
file(MAKE_DIRECTORY "${TEST_ROOT}/sbom")
file(WRITE "${TEST_ROOT}/kept" "payload")

set(records "")
foreach(name kept omitted)
  string(APPEND records
    "FileName: ./${name}\nSPDXID: SPDXRef-PackagedFile-${name}\n"
    "FileType: BINARY\nFileChecksum: SHA1: 0000000000000000000000000000000000000000\n"
    "LicenseConcluded: NOASSERTION\nFileCopyrightText: NOASSERTION\n\n"
    "Relationship: SPDXRef-Package-core CONTAINS SPDXRef-PackagedFile-${name}\n"
    "Relationship: SPDXRef-PackagedFile-${name} GENERATED_FROM NOASSERTION\n\n")
endforeach()
set(document "${TEST_ROOT}/sbom/core.spdx")
set(dependent "${TEST_ROOT}/sbom/dependent.spdx")
file(WRITE "${document}"
  "DocumentNamespace: https://example.invalid/core\n\nPackageName: core\n"
  "SPDXID: SPDXRef-Package-core\n"
  "PackageVerificationCode: 0000000000000000000000000000000000000000\n\n${records}")
file(WRITE "${dependent}"
  "DocumentNamespace: https://example.invalid/dependent\n"
  "ExternalDocumentRef: DocumentRef-core https://example.invalid/core SHA1: "
  "0000000000000000000000000000000000000000\n")
set(refresh "${TEST_ROOT}/refresh.cmake")
file(WRITE "${refresh}" "include(\"${SOURCE_ROOT}/CMake/RefreshSpdx.cmake\")\n"
  "bext_refresh_spdx(\"${TEST_ROOT}\" \${REFRESH_OPTIONS})\n")

file(READ "${document}" original HEX)
execute_process(COMMAND "${CMAKE_COMMAND}" -P "${refresh}" RESULT_VARIABLE result)
if(result EQUAL 0)
  message(FATAL_ERROR "Missing SPDX content was accepted without PRUNE_MISSING")
endif()
file(READ "${document}" unchanged HEX)
if(NOT original STREQUAL unchanged)
  message(FATAL_ERROR "Failed SPDX refresh modified its input")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" -DREFRESH_OPTIONS=PRUNE_MISSING -P "${refresh}"
  RESULT_VARIABLE result ERROR_VARIABLE error)
if(NOT result EQUAL 0)
  message(FATAL_ERROR "SPDX refresh failed: ${error}")
endif()
file(READ "${document}" content)
bext_test_require_not_contains("${content}" "omitted" "SPDX pruning")
file(SHA1 "${TEST_ROOT}/kept" checksum)
string(SHA1 verification "${checksum}")
bext_test_require_contains("${content}" "FileChecksum: SHA1: ${checksum}" "SPDX file hash")
bext_test_require_contains("${content}" "PackageVerificationCode: ${verification}"
  "SPDX verification code")
file(SHA1 "${document}" document_hash)
file(READ "${dependent}" dependent_content)
bext_test_require_contains("${dependent_content}" "${document_hash}" "External SPDX hash")

file(READ "${document}" first_document HEX)
file(READ "${dependent}" first_dependent HEX)
execute_process(COMMAND "${CMAKE_COMMAND}" -DREFRESH_OPTIONS=PRUNE_MISSING -P "${refresh}"
  COMMAND_ERROR_IS_FATAL ANY)
file(READ "${document}" second_document HEX)
file(READ "${dependent}" second_dependent HEX)
if(NOT first_document STREQUAL second_document OR NOT first_dependent STREQUAL second_dependent)
  message(FATAL_ERROR "SPDX refresh is not idempotent")
endif()

file(REMOVE "${TEST_ROOT}/kept")
execute_process(COMMAND "${CMAKE_COMMAND}" -DREFRESH_OPTIONS=PRUNE_MISSING -P "${refresh}"
  COMMAND_ERROR_IS_FATAL ANY)
file(READ "${document}" content)
bext_test_require_not_contains("${content}" "FileName:" "Empty SPDX pruning")
string(SHA1 empty_hash "")
bext_test_require_contains("${content}" "PackageVerificationCode: ${empty_hash}"
  "Empty SPDX verification code")
