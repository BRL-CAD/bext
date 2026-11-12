cmake_minimum_required(VERSION 3.26)

# Finalize the bundled bext output and publish its file-processing manifest.

foreach(required_var
    BEXT_INSTALL_ROOT
    BEXT_MANIFEST
    BEXT_INSTALL_EXCLUDE_MANIFEST
    BEXT_INSTALL_EXCLUDE_RULES
    BEXT_COMPONENT_MANIFEST
    BEXT_COMPONENT_OWNERSHIP_RULES
    BEXT_ACTIVE_COMPONENTS
    BEXT_SBOM_SELECTORS
    BEXT_SBOM
    BEXT_SOURCE_ROOT
    BEXT_BINARY_ROOT
    BEXT_NOINSTALL_ROOT
    BEXT_STRCLEAR
    BEXT_SYSTEM_NAME
    BIN_DIR
    LIB_DIR)
  if (NOT DEFINED ${required_var} OR "${${required_var}}" STREQUAL "")
    message(FATAL_ERROR "${required_var} is required")
  endif ()
endforeach()

function(bext_json_escape outvar value)
  set(escaped "${value}")
  string(REPLACE "\\" "\\\\" escaped "${escaped}")
  string(REPLACE "\"" "\\\"" escaped "${escaped}")
  string(REPLACE "\r" "\\r" escaped "${escaped}")
  string(REPLACE "\n" "\\n" escaped "${escaped}")
  set(${outvar} "${escaped}" PARENT_SCOPE)
endfunction()

function(bext_write_json_array manifest key values)
  file(APPEND "${manifest}" "  \"${key}\": [\n")
  set(first TRUE)
  foreach(value ${${values}})
    bext_json_escape(escaped "${value}")
    if (first)
      set(first FALSE)
    else ()
      file(APPEND "${manifest}" ",\n")
    endif ()
    file(APPEND "${manifest}" "    \"${escaped}\"")
  endforeach()
  file(APPEND "${manifest}" "\n  ]")
endfunction()

function(bext_write_file_list outvar filename values)
  file(WRITE "${filename}" "")
  foreach(value ${${values}})
    file(APPEND "${filename}" "${value}\n")
  endforeach()
  set(${outvar} "${filename}" PARENT_SCOPE)
endfunction()

function(bext_content_fingerprints outvar root label file_list_var)
  set(records "")
  foreach(relative IN LISTS ${file_list_var})
    set(path "${root}/${relative}")
    if (IS_SYMLINK "${path}")
      file(READ_SYMLINK "${path}" value)
      string(APPEND records "L ${label}/${relative} ${value}\n")
    else ()
      file(SHA256 "${path}" value)
      string(APPEND records "F ${label}/${relative} ${value}\n")
    endif ()
  endforeach()
  set(${outvar} "${records}" PARENT_SCOPE)
endfunction()

macro(bext_claim_component_file relative component)
  string(SHA256 ownership_key "${relative}")
  list(APPEND ownership_components_${ownership_key} "${component}")
endmacro()

function(bext_relative_path outvar path)
  file(RELATIVE_PATH relative "${BEXT_INSTALL_ROOT}" "${path}")
  string(REPLACE "\\" "/" relative "${relative}")
  set(${outvar} "${relative}" PARENT_SCOPE)
endfunction()

function(bext_is_skipped path outvar)
  if ("${path}" MATCHES "(^|/)(encodings|man|msgs)(/|$)")
    set(${outvar} TRUE PARENT_SCOPE)
  else ()
    set(${outvar} FALSE PARENT_SCOPE)
  endif ()
endfunction()

function(bext_is_cmake_file path outvar)
  if ("${path}" MATCHES "(Deps|Modules|Version|Targets|Config)\\.cmake$" OR
      "${path}" MATCHES "\\.pc$")
    set(${outvar} TRUE PARENT_SCOPE)
  else ()
    set(${outvar} FALSE PARENT_SCOPE)
  endif ()
endfunction()

function(bext_run_binary_clear files)
  if (NOT files)
    return()
  endif ()

  set(clear_targets
    "${BEXT_SOURCE_ROOT}"
    "${BEXT_BINARY_ROOT}"
    "${BEXT_NOINSTALL_ROOT}"
    "${BEXT_INSTALL_ROOT}"
  )
  set(file_list "${BEXT_BINARY_ROOT}/CMakeFiles/bext-binary-files.txt")
  bext_write_file_list(file_list "${file_list}" files)

  set(command "${BEXT_STRCLEAR}" -p -b -c --files "${file_list}")
  list(APPEND command ${clear_targets})
  execute_process(
    COMMAND ${command}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
  )
  if (NOT result EQUAL 0)
    message(FATAL_ERROR "strclear binary cleanup failed: ${error}${output}")
  endif ()
endfunction()

function(bext_update_rpath_group files rpath)
  if (NOT files OR NOT BEXT_PLIEF)
    return()
  endif ()

  execute_process(
    COMMAND "${BEXT_PLIEF}" --help
    RESULT_VARIABLE help_result
    OUTPUT_VARIABLE help_output
    ERROR_QUIET
  )
  if (NOT help_result EQUAL 0)
    message(FATAL_ERROR "Unable to query ${BEXT_PLIEF}")
  endif ()

  set(rpath_args --set-rpath "${rpath}")
  if ("${help_output}" MATCHES "--set-rpath-if-needed")
    list(APPEND rpath_args
      --set-rpath-if-needed
      --stale-rpath-prefix "${BEXT_INSTALL_ROOT}"
      --stale-rpath-prefix "${BEXT_BINARY_ROOT}"
    )
    if ("${help_output}" MATCHES "--set-rpath-if-needed-prepend")
      list(APPEND rpath_args --set-rpath-if-needed-prepend)
    endif ()
  endif ()

  if ("${help_output}" MATCHES "--files")
    string(SHA256 key "${rpath}")
    set(file_list "${BEXT_BINARY_ROOT}/CMakeFiles/bext-rpath-${key}.txt")
    bext_write_file_list(file_list "${file_list}" files)
    execute_process(
      COMMAND "${BEXT_PLIEF}" ${rpath_args} --files "${file_list}"
      RESULT_VARIABLE result
      OUTPUT_VARIABLE output
      ERROR_VARIABLE error
    )
    if (NOT result EQUAL 0)
      message(FATAL_ERROR "RPATH update failed: ${error}${output}")
    endif ()
  else ()
    foreach(file ${files})
      execute_process(
        COMMAND "${BEXT_PLIEF}" ${rpath_args} "${file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
      )
      if (NOT result EQUAL 0)
        message(FATAL_ERROR "RPATH update failed for ${file}: ${error}${output}")
      endif ()
    endforeach()
  endif ()
endfunction()

function(bext_run_rpath_update files)
  if("${BEXT_SYSTEM_NAME}" STREQUAL "Darwin")
    set(origin "@loader_path")
  else()
    set(origin "$ORIGIN")
  endif()
  set(groups)
  foreach(path IN LISTS files)
    get_filename_component(directory "${path}" DIRECTORY)
    file(RELATIVE_PATH suffix "${directory}" "${BEXT_INSTALL_ROOT}/${LIB_DIR}")
    if(suffix STREQUAL "")
      set(rpath "${origin}")
    else()
      set(rpath "${origin}/${suffix}")
    endif()
    string(SHA256 key "${rpath}")
    list(APPEND groups "${key}")
    set(rpath_${key} "${rpath}")
    list(APPEND files_${key} "${path}")
  endforeach()
  list(REMOVE_DUPLICATES groups)
  foreach(key IN LISTS groups)
    bext_update_rpath_group("${files_${key}}" "${rpath_${key}}")
  endforeach()
endfunction()

function(bext_run_text_replace files target replacement)
  if (NOT files OR "${target}" STREQUAL "")
    return()
  endif ()

  set(text_paths)
  foreach(relative ${files})
    list(APPEND text_paths "${BEXT_INSTALL_ROOT}/${relative}")
  endforeach()
  set(file_list "${BEXT_BINARY_ROOT}/CMakeFiles/bext-text-files.txt")
  bext_write_file_list(file_list "${file_list}" text_paths)
  execute_process(
    COMMAND "${BEXT_STRCLEAR}" -p --files "${file_list}" "${target}" "${replacement}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
  )
  if (NOT result EQUAL 0)
    message(FATAL_ERROR "strclear text replacement failed for ${target}: ${error}${output}")
  endif ()
endfunction()

function(bext_run_component_hooks phase)
  foreach(component IN LISTS active_components)
    include("${BEXT_SOURCE_ROOT}/${component}/${phase}.cmake" OPTIONAL)
  endforeach()
endfunction()

file(STRINGS "${BEXT_ACTIVE_COMPONENTS}" active_components)
bext_run_component_hooks(PrepareInstall)

file(MAKE_DIRECTORY "${BEXT_BINARY_ROOT}/CMakeFiles")
file(GLOB_RECURSE install_tree_files
  LIST_DIRECTORIES false
  RELATIVE "${BEXT_INSTALL_ROOT}"
  "${BEXT_INSTALL_ROOT}/*"
)
list(SORT install_tree_files)

# Native install manifests define files installed by this configured build.
# Explicit ownership rules cover files copied by wrapper logic outside those
# native manifests. Anything else may be residue from another configuration;
# retain it on disk, but exclude it from this build's manifest and SBOM.
file(GLOB_RECURSE native_install_manifests
  LIST_DIRECTORIES false
  "${BEXT_BINARY_ROOT}/*/install_manifest.txt"
)
set(installed_files)
foreach(native_manifest ${native_install_manifests})
  file(RELATIVE_PATH manifest_relative "${BEXT_BINARY_ROOT}" "${native_manifest}")
  string(REPLACE "\\" "/" manifest_relative "${manifest_relative}")
  string(REGEX REPLACE "/.*$" "" component "${manifest_relative}")
  string(TOLOWER "${component}" component)
  list(FIND active_components "${component}" active_component_index)
  if(active_component_index EQUAL -1)
    continue()
  endif()
  file(STRINGS "${native_manifest}" native_installed_files)
  foreach(installed_path ${native_installed_files})
    file(RELATIVE_PATH relative "${BEXT_INSTALL_ROOT}" "${installed_path}")
    string(REPLACE "\\" "/" relative "${relative}")
    if(NOT relative MATCHES "(^|/)\\.\\.(/|$)" AND EXISTS "${BEXT_INSTALL_ROOT}/${relative}")
      list(APPEND installed_files "${relative}")
      bext_claim_component_file("${relative}" "${component}")
    endif()
  endforeach()
endforeach()
file(STRINGS "${BEXT_COMPONENT_OWNERSHIP_RULES}" component_ownership_rules)
foreach(rule ${component_ownership_rules})
  string(FIND "${rule}" "|" separator)
  if(separator LESS 1)
    message(FATAL_ERROR "Invalid component ownership rule: ${rule}")
  endif()
  string(SUBSTRING "${rule}" 0 ${separator} component)
  list(FIND active_components "${component}" active_component_index)
  if(active_component_index EQUAL -1)
    continue()
  endif()
  math(EXPR pattern_start "${separator} + 1")
  string(SUBSTRING "${rule}" ${pattern_start} -1 pattern)
  foreach(relative ${install_tree_files})
    if("${relative}" MATCHES "${pattern}")
      list(APPEND installed_files "${relative}")
      string(SHA256 ownership_key "${relative}")
      if(NOT explicit_ownership_${ownership_key})
        set(ownership_components_${ownership_key})
        set(explicit_ownership_${ownership_key} TRUE)
      endif()
      bext_claim_component_file("${relative}" "${component}")
    endif()
  endforeach()
endforeach()
list(REMOVE_DUPLICATES installed_files)
list(SORT installed_files)
set(untracked_install_files ${install_tree_files})
if(installed_files)
  list(REMOVE_ITEM untracked_install_files ${installed_files})
endif()
list(SORT untracked_install_files)
set(untracked_report "${BEXT_BINARY_ROOT}/bext-untracked-install-files.txt")
if(untracked_install_files)
  list(LENGTH untracked_install_files untracked_install_count)
  bext_write_file_list(untracked_report "${untracked_report}" untracked_install_files)
  message(STATUS
    "Excluded ${untracked_install_count} files not recorded by this build's install manifests; see ${untracked_report}")
else()
  file(REMOVE "${untracked_report}")
endif()

set(classify_files)
set(skipped_files)
foreach(relative ${installed_files})
  set(path "${BEXT_INSTALL_ROOT}/${relative}")
  if (IS_SYMLINK "${path}")
    list(APPEND skipped_files "${relative}")
    continue()
  endif ()
  bext_is_skipped("${relative}" skipped)
  if (skipped)
    list(APPEND skipped_files "${relative}")
  else ()
    list(APPEND classify_files "${path}")
  endif ()
endforeach()

set(text_files)
set(binary_probe_files)
if (classify_files)
  execute_process(
    COMMAND "${BEXT_STRCLEAR}" --help
    RESULT_VARIABLE strclear_help_result
    OUTPUT_VARIABLE strclear_help
    ERROR_QUIET
  )
  if (NOT strclear_help_result EQUAL 0)
    message(FATAL_ERROR "Unable to query ${BEXT_STRCLEAR}")
  endif ()

  if ("${strclear_help}" MATCHES "--classify" AND "${strclear_help}" MATCHES "--files")
    set(classify_list "${BEXT_BINARY_ROOT}/CMakeFiles/bext-classify-files.txt")
    bext_write_file_list(classify_list "${classify_list}" classify_files)
    execute_process(
      COMMAND "${BEXT_STRCLEAR}" --classify --files "${classify_list}"
      RESULT_VARIABLE classify_result
      OUTPUT_VARIABLE classify_output
      ERROR_VARIABLE classify_error
    )
    if (NOT classify_result EQUAL 0)
      message(FATAL_ERROR "strclear classification failed: ${classify_error}${classify_output}")
    endif ()
    string(REPLACE "\r\n" "\n" classify_output "${classify_output}")
    string(REPLACE "\n" ";" classify_records "${classify_output}")
    foreach(record ${classify_records})
      if ("${record}" STREQUAL "")
        continue()
      endif ()
      string(JSON type ERROR_VARIABLE json_error GET "${record}" type)
      string(JSON path ERROR_VARIABLE path_error GET "${record}" path)
      if (NOT "${json_error}" STREQUAL "NOTFOUND" OR NOT "${path_error}" STREQUAL "NOTFOUND")
        message(FATAL_ERROR "Invalid strclear classification record: ${record}")
      endif ()
      bext_relative_path(relative "${path}")
      if ("${type}" STREQUAL "TEXT")
        list(APPEND text_files "${relative}")
      elseif ("${type}" STREQUAL "BINARY")
        list(APPEND binary_probe_files "${relative}")
      else ()
        message(FATAL_ERROR "Unknown strclear classification: ${type}")
      endif ()
    endforeach()
  else ()
    foreach(path ${classify_files})
      execute_process(
        COMMAND "${BEXT_STRCLEAR}" -B "${path}"
        RESULT_VARIABLE binary_result
        ERROR_QUIET
      )
      bext_relative_path(relative "${path}")
      if (binary_result EQUAL 0)
        list(APPEND binary_probe_files "${relative}")
      elseif (binary_result EQUAL 1)
        list(APPEND text_files "${relative}")
      else ()
        message(FATAL_ERROR "strclear could not classify ${path}")
      endif ()
    endforeach()
  endif ()
endif ()

set(rpath_files)
set(binary_files)
if (binary_probe_files)
  if (BEXT_PLIEF)
    execute_process(
      COMMAND "${BEXT_PLIEF}" --help
      RESULT_VARIABLE plief_help_result
      OUTPUT_VARIABLE plief_help
      ERROR_QUIET
    )
  else ()
    set(plief_help_result 1)
  endif ()

  if (plief_help_result EQUAL 0 AND "${plief_help}" MATCHES "--classify" AND "${plief_help}" MATCHES "--files")
    set(plief_list "${BEXT_BINARY_ROOT}/CMakeFiles/bext-plief-files.txt")
    set(plief_paths)
    foreach(relative ${binary_probe_files})
      list(APPEND plief_paths "${BEXT_INSTALL_ROOT}/${relative}")
    endforeach()
    bext_write_file_list(plief_list "${plief_list}" plief_paths)
    execute_process(
      COMMAND "${BEXT_PLIEF}" --classify --files "${plief_list}"
      RESULT_VARIABLE plief_result
      OUTPUT_VARIABLE plief_output
      ERROR_VARIABLE plief_error
    )
    if (NOT plief_result EQUAL 0)
      message(FATAL_ERROR "plief classification failed: ${plief_error}${plief_output}")
    endif ()
    string(REPLACE "\r\n" "\n" plief_output "${plief_output}")
    string(REPLACE "\n" ";" plief_records "${plief_output}")
    foreach(record ${plief_records})
      if ("${record}" STREQUAL "")
        continue()
      endif ()
      string(JSON type ERROR_VARIABLE json_error GET "${record}" type)
      string(JSON path ERROR_VARIABLE path_error GET "${record}" path)
      if (NOT "${json_error}" STREQUAL "NOTFOUND" OR NOT "${path_error}" STREQUAL "NOTFOUND")
        message(FATAL_ERROR "Invalid plief classification record: ${record}")
      endif ()
      bext_relative_path(relative "${path}")
      if ("${type}" STREQUAL "ELF")
        list(APPEND rpath_files "${relative}")
      elseif ("${type}" STREQUAL "OTHER")
        list(APPEND binary_files "${relative}")
      else ()
        message(FATAL_ERROR "Unknown plief classification: ${type}")
      endif ()
    endforeach()
  else ()
    if ("${BEXT_SYSTEM_NAME}" STREQUAL "Darwin")
      foreach(relative ${binary_probe_files})
        execute_process(
          COMMAND otool -l "${BEXT_INSTALL_ROOT}/${relative}"
          RESULT_VARIABLE otool_result
          OUTPUT_VARIABLE otool_output
          ERROR_QUIET
        )
        if (otool_result EQUAL 0 AND
            NOT "${otool_output}" MATCHES "Archive|not an object")
          list(APPEND rpath_files "${relative}")
        else ()
          list(APPEND binary_files "${relative}")
        endif ()
      endforeach()
    else ()
      list(APPEND binary_files ${binary_probe_files})
    endif ()
  endif ()
else ()
  set(plief_help_result 1)
endif ()

list(SORT text_files)
list(SORT rpath_files)
list(SORT binary_files)
set(cmake_files)
set(plain_text_files)
foreach(relative ${text_files})
  bext_is_cmake_file("${relative}" is_cmake)
  if (is_cmake)
    list(APPEND cmake_files "${relative}")
  else ()
    list(APPEND plain_text_files "${relative}")
  endif ()
endforeach()
list(SORT cmake_files)
list(SORT plain_text_files)

set(install_excluded_files ${untracked_install_files})
file(STRINGS "${BEXT_INSTALL_EXCLUDE_RULES}" install_exclude_patterns)
foreach(relative ${installed_files})
  foreach(pattern ${install_exclude_patterns})
    if("${relative}" MATCHES "${pattern}")
      list(APPEND install_excluded_files "${relative}")
      break()
    endif()
  endforeach()
endforeach()
list(REMOVE_DUPLICATES install_excluded_files)
list(SORT install_excluded_files)

set(component_records)
set(unowned_files)
set(conflicting_files)
foreach(relative ${installed_files})
  list(FIND install_excluded_files "${relative}" excluded_file_index)
  if(NOT excluded_file_index EQUAL -1)
    continue()
  endif()
  string(SHA256 ownership_key "${relative}")
  set(owners ${ownership_components_${ownership_key}})
  list(REMOVE_DUPLICATES owners)
  list(LENGTH owners owner_count)
  if(owner_count EQUAL 0)
    list(APPEND unowned_files "${relative}")
  elseif(owner_count GREATER 1)
    list(JOIN owners "," owner_text)
    list(APPEND conflicting_files "${relative}: ${owner_text}")
  else()
    list(GET owners 0 component)
    list(APPEND component_records "${relative}|${component}")
  endif()
endforeach()
if(unowned_files OR conflicting_files)
  list(JOIN unowned_files "\n  " unowned_text)
  list(JOIN conflicting_files "\n  " conflicting_text)
  message(FATAL_ERROR
    "Bext component ownership is incomplete or ambiguous.\n"
    "Unowned files:\n  ${unowned_text}\n"
    "Conflicting files:\n  ${conflicting_text}")
endif()
list(SORT component_records)

# Some projects ship source for optional third-party libraries. Record only
# packages selected by their completed configure so downstream installed
# SBOMs do not mistake unused bundled source for code present in the binaries.
include("${BEXT_SBOM_SELECTORS}")
set(selection_components)
set(selected_package_records)
foreach(selector_id IN LISTS BEXT_SBOM_SELECTOR_IDS)
  set(selector_prefix "BEXT_SBOM_SELECTOR_${selector_id}")
  set(component "${${selector_prefix}_COMPONENT}")
  list(FIND active_components "${component}" active_component_index)
  if(active_component_index EQUAL -1)
    continue()
  endif()
  set(selector_script "${${selector_prefix}_SCRIPT}")
  set(selector_function "${${selector_prefix}_FUNCTION}")
  set(selector_cache "${${selector_prefix}_CACHE}")
  set(preserved_selector_cache "${${selector_prefix}_PRESERVED_CACHE}")
  set(selector_arguments "${${selector_prefix}_ARGUMENTS}")
  if(NOT EXISTS "${selector_script}")
    message(FATAL_ERROR "Installed SBOM selector for ${component} is unavailable: ${selector_script}")
  endif()
  if(NOT EXISTS "${selector_cache}")
    set(selector_cache "${preserved_selector_cache}")
  endif()
  if(NOT EXISTS "${selector_cache}")
    message(FATAL_ERROR
      "${component} is active but neither its configure cache nor its preserved "
      "installed SBOM cache is available: ${${selector_prefix}_CACHE}; ${preserved_selector_cache}")
  endif()
  include("${selector_script}")
  if(NOT COMMAND "${selector_function}")
    message(FATAL_ERROR "Installed SBOM selector ${selector_script} does not define ${selector_function}")
  endif()
  unset(selected_packages)
  cmake_language(CALL "${selector_function}" selected_packages "${selector_cache}" ${selector_arguments})
  if(NOT DEFINED selected_packages)
    message(FATAL_ERROR "Installed SBOM selector ${selector_function} did not return a package list for ${component}")
  endif()
  list(APPEND selection_components "${component}")
  foreach(spdx_id IN LISTS selected_packages)
    list(APPEND selected_package_records "${component}|${spdx_id}")
  endforeach()
endforeach()

include("${BEXT_SOURCE_ROOT}/CMake/BextDependencyInventory.cmake")
bext_collect_dependency_inventory("${BEXT_SOURCE_ROOT}")
bext_inventory_package_records(inventory_package_records)
set(package_records)
foreach(record ${inventory_package_records})
  string(REPLACE "|" ";" record_parts "${record}")
  list(GET record_parts 0 component)
  list(FIND active_components "${component}" active_component_index)
  if(active_component_index EQUAL -1)
    continue()
  endif()
  list(GET record_parts 2 spdx_id)
  list(FIND selection_components "${component}" selection_component_index)
  if(NOT selection_component_index EQUAL -1)
    list(FIND selected_package_records "${component}|${spdx_id}" selected_package_index)
    if(selected_package_index EQUAL -1)
      continue()
    endif()
  endif()
  list(APPEND package_records "${record}")
endforeach()
list(REMOVE_DUPLICATES package_records)
list(SORT package_records)

# Normalize the install prefix first, then replace its enclosing build and
# source roots.  strclear -p preserves the replacement root, so subsequent
# passes also leave already-correct install paths intact.
set(text_paths ${text_files})
foreach(clear_target
    "${BEXT_INSTALL_ROOT}"
    "${BEXT_NOINSTALL_ROOT}"
    "${BEXT_BINARY_ROOT}"
    "${BEXT_SOURCE_ROOT}")
  bext_run_text_replace("${text_paths}" "${clear_target}" "${BEXT_INSTALL_ROOT}")
endforeach()

# pkg-config locates metadata through pcfiledir, including after relocation.
foreach(relative IN LISTS text_files)
  if(NOT relative MATCHES "[.]pc$")
    continue()
  endif()
  set(path "${BEXT_INSTALL_ROOT}/${relative}")
  get_filename_component(directory "${path}" DIRECTORY)
  file(RELATIVE_PATH to_root "${directory}" "${BEXT_INSTALL_ROOT}")
  string(REGEX REPLACE "/+$" "" to_root "${to_root}")
  file(READ "${path}" content)
  string(REPLACE "${BEXT_INSTALL_ROOT}" "\${prefix}" content "${content}")
  if(content MATCHES "(^|\n)prefix=")
    string(REGEX REPLACE "(^|\n)prefix=[^\n]*" "\\1prefix=\${pcfiledir}/${to_root}" content "${content}")
  else()
    string(PREPEND content "prefix=\${pcfiledir}/${to_root}\n")
  endif()
  file(WRITE "${path}.tmp" "${content}")
  file(COPY_FILE "${path}.tmp" "${path}" ONLY_IF_DIFFERENT)
  file(REMOVE "${path}.tmp")
endforeach()

# Clear producer paths before writing RPATHs relative to each installed file.
set(all_binary_files ${rpath_files} ${binary_files})
set(binary_paths)
set(rpath_paths)
foreach(relative ${all_binary_files})
  list(APPEND binary_paths "${BEXT_INSTALL_ROOT}/${relative}")
endforeach()
foreach(relative ${rpath_files})
  list(APPEND rpath_paths "${BEXT_INSTALL_ROOT}/${relative}")
endforeach()
set(binary_cleanup_paths ${binary_paths})
if ("${BEXT_SYSTEM_NAME}" STREQUAL "Darwin" AND
    NOT BEXT_PLIEF)
  # Without plief, preserve Mach-O RPATH load commands for BRL-CAD's
  # install_name_tool staging pass.
  set(binary_cleanup_paths)
  foreach(relative ${binary_files})
    list(APPEND binary_cleanup_paths "${BEXT_INSTALL_ROOT}/${relative}")
  endforeach()
endif ()
bext_run_binary_clear("${binary_cleanup_paths}")
bext_run_rpath_update("${rpath_paths}")

bext_run_component_hooks(FinalizeInstall)

file(WRITE "${BEXT_MANIFEST}.tmp" "{\n")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"schema\": 1,\n")
bext_json_escape(platform "${BEXT_SYSTEM_NAME}")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"platform\": \"${platform}\",\n")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"install_root\": \"install\",\n")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"generated_by\": \"bext\",\n")
# A consumer may reach the bundle through a different alias, or after a move.
# Record the producer's spellings instead of trying to infer them downstream.
file(REAL_PATH "${BEXT_INSTALL_ROOT}" real_install_root)
set(install_prefixes "${BEXT_INSTALL_ROOT}" "${real_install_root}")
list(REMOVE_DUPLICATES install_prefixes)
bext_write_json_array("${BEXT_MANIFEST}.tmp" "install_prefixes" install_prefixes)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "files" installed_files)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "rpath" rpath_files)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "binary" binary_files)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "cmake" cmake_files)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "text" plain_text_files)
file(APPEND "${BEXT_MANIFEST}.tmp" "\n}\n")
file(COPY_FILE "${BEXT_MANIFEST}.tmp" "${BEXT_MANIFEST}" ONLY_IF_DIFFERENT)
file(REMOVE "${BEXT_MANIFEST}.tmp")

string(ASCII 34 json_quote)
file(WRITE "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "{\n")
file(APPEND "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "  ${json_quote}schema${json_quote}: 1,\n")
file(APPEND "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "  ${json_quote}platform${json_quote}: ${json_quote}${platform}${json_quote},\n")
file(APPEND "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "  ${json_quote}install_root${json_quote}: ${json_quote}install${json_quote},\n")
file(APPEND "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "  ${json_quote}generated_by${json_quote}: ${json_quote}bext${json_quote},\n")
bext_write_json_array("${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "files" install_excluded_files)
file(APPEND "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "\n}\n")
file(COPY_FILE "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp" "${BEXT_INSTALL_EXCLUDE_MANIFEST}" ONLY_IF_DIFFERENT)
file(REMOVE "${BEXT_INSTALL_EXCLUDE_MANIFEST}.tmp")

file(WRITE "${BEXT_COMPONENT_MANIFEST}.tmp" "{\n")
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ${json_quote}schema${json_quote}: ${json_quote}https://brlcad.org/schema/bext-component-manifest-v2${json_quote},\n")
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ${json_quote}platform${json_quote}: ${json_quote}${platform}${json_quote},\n")
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ${json_quote}install_root${json_quote}: ${json_quote}install${json_quote},\n")
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ${json_quote}generated_by${json_quote}: ${json_quote}bext${json_quote},\n")
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ${json_quote}files${json_quote}: [\n")
list(LENGTH component_records component_record_count)
set(component_record_index 0)
foreach(record ${component_records})
  math(EXPR component_record_index "${component_record_index} + 1")
  string(REPLACE "|" ";" record_parts "${record}")
  list(GET record_parts 0 relative)
  list(GET record_parts 1 component)
  bext_json_escape(relative_json "${relative}")
  bext_json_escape(component_json "${component}")
  file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp"
    "    {${json_quote}path${json_quote}: ${json_quote}${relative_json}${json_quote}, ${json_quote}component${json_quote}: ${json_quote}${component_json}${json_quote}}")
  if(component_record_index LESS component_record_count)
    file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" ",\n")
  else()
    file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "\n")
  endif()
endforeach()
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ],\n")
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ${json_quote}packages${json_quote}: [\n")
list(LENGTH package_records package_count)
set(package_index 0)
foreach(record ${package_records})
  math(EXPR package_index "${package_index} + 1")
  string(REPLACE "|" ";" record_parts "${record}")
  list(GET record_parts 0 component)
  list(GET record_parts 1 id)
  list(GET record_parts 2 spdx_id)
  list(GET record_parts 3 primary)
  bext_inventory_get(package_output "${component}" OUTPUT)
  string(TOLOWER "${primary}" primary)
  bext_json_escape(component_json "${component}")
  bext_json_escape(id_json "${id}")
  bext_json_escape(spdx_id_json "${spdx_id}")
  bext_json_escape(package_output_json "${package_output}")
  file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp"
    "    {${json_quote}component${json_quote}: ${json_quote}${component_json}${json_quote}, ${json_quote}id${json_quote}: ${json_quote}${id_json}${json_quote}, ${json_quote}spdx_id${json_quote}: ${json_quote}${spdx_id_json}${json_quote}, ${json_quote}primary${json_quote}: ${primary}, ${json_quote}output${json_quote}: ${json_quote}${package_output_json}${json_quote}}")
  if(package_index LESS package_count)
    file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" ",\n")
  else()
    file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "\n")
  endif()
endforeach()
file(APPEND "${BEXT_COMPONENT_MANIFEST}.tmp" "  ]\n}\n")
file(COPY_FILE "${BEXT_COMPONENT_MANIFEST}.tmp" "${BEXT_COMPONENT_MANIFEST}" ONLY_IF_DIFFERENT)
file(REMOVE "${BEXT_COMPONENT_MANIFEST}.tmp")

# Existing files are watched by downstream builds.  This list also detects
# additions and removals without changing its timestamp on a no-op build.
file(GLOB_RECURSE noinstall_files
  LIST_DIRECTORIES false
  RELATIVE "${BEXT_NOINSTALL_ROOT}"
  "${BEXT_NOINSTALL_ROOT}/*"
)
list(REMOVE_ITEM noinstall_files "build-stamp")
list(SORT noinstall_files)
set(noinstall_inventory "${BEXT_BINARY_ROOT}/CMakeFiles/bext-noinstall-files.txt")
bext_write_file_list(noinstall_inventory "${noinstall_inventory}" noinstall_files)
file(COPY_FILE "${noinstall_inventory}" "${BEXT_NOINSTALL_ROOT}/build-stamp"
  ONLY_IF_DIFFERENT)

# Finalized binaries and config files may be rewritten on every install even
# when their resulting bytes are unchanged.  Publish one stable dependency for
# downstream builds instead of making them watch every output timestamp.
bext_content_fingerprints(installed_content "${BEXT_INSTALL_ROOT}" "install"
  installed_files)
bext_content_fingerprints(noinstall_content "${BEXT_NOINSTALL_ROOT}" "noinstall"
  noinstall_files)
file(SHA256 "${BEXT_MANIFEST}" manifest_digest)
file(SHA256 "${BEXT_INSTALL_EXCLUDE_MANIFEST}" install_exclude_manifest_digest)
file(SHA256 "${BEXT_COMPONENT_MANIFEST}" component_manifest_digest)
file(SHA256 "${BEXT_SBOM}" sbom_digest)
string(SHA256 content_digest
  "${installed_content}${noinstall_content}M ${manifest_digest}\nX ${install_exclude_manifest_digest}\nC ${component_manifest_digest}\nS ${sbom_digest}\n")
set(content_stamp "${BEXT_BINARY_ROOT}/bext-content-stamp")
file(WRITE "${content_stamp}.tmp" "${content_digest}\n")
file(COPY_FILE "${content_stamp}.tmp" "${content_stamp}" ONLY_IF_DIFFERENT)
file(REMOVE "${content_stamp}.tmp")
message(STATUS "Generated bext install manifest: ${BEXT_MANIFEST}")
message(STATUS "Generated bext install exclusion manifest: ${BEXT_INSTALL_EXCLUDE_MANIFEST}")
message(STATUS "Generated bext component manifest: ${BEXT_COMPONENT_MANIFEST}")
