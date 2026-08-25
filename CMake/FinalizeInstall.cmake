# Finalize the bundled bext output and publish its file-processing manifest.

foreach(required_var
    BEXT_INSTALL_ROOT
    BEXT_MANIFEST
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

function(bext_relative_path outvar path)
  file(RELATIVE_PATH relative "${BEXT_INSTALL_ROOT}" "${path}")
  string(REPLACE "\\" "/" relative "${relative}")
  set(${outvar} "${relative}" PARENT_SCOPE)
endfunction()

function(bext_is_skipped path outvar)
  if ("${path}" MATCHES "(^|/)(encodings|include|man|msgs)(/|$)")
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

function(bext_run_rpath_update files)
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

  set(rpath_args --set-rpath "${BEXT_INSTALL_ROOT}/${LIB_DIR}")
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
    set(file_list "${BEXT_BINARY_ROOT}/CMakeFiles/bext-rpath-files.txt")
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

file(MAKE_DIRECTORY "${BEXT_BINARY_ROOT}/CMakeFiles")
file(GLOB_RECURSE installed_files
  LIST_DIRECTORIES false
  RELATIVE "${BEXT_INSTALL_ROOT}"
  "${BEXT_INSTALL_ROOT}/*"
)
list(SORT installed_files)

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

# Replace paths that only have meaning while bext is being built.  Keep the
# install prefix intact: downstream projects replace this canonical prefix
# with their own staging prefix after copying the finalized tree.
set(text_paths ${text_files})
foreach(path ${text_paths})
  set(text_path "${BEXT_INSTALL_ROOT}/${path}")
  if (UNIX)
    file(CHMOD "${text_path}"
      PERMISSIONS OWNER_READ OWNER_WRITE
                  GROUP_READ GROUP_WRITE
                  WORLD_READ)
  endif ()
endforeach()
foreach(clear_target
    "${BEXT_SOURCE_ROOT}"
    "${BEXT_BINARY_ROOT}"
    "${BEXT_NOINSTALL_ROOT}")
  bext_run_text_replace("${text_paths}" "${clear_target}" "${BEXT_INSTALL_ROOT}")
endforeach()

# Clear paths before restoring the canonical bext RPATH.  Clearing the install
# root after the RPATH update would also clear the newly written RPATH.
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
foreach(path ${binary_paths})
  if (UNIX)
    file(CHMOD "${path}"
      PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                  GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
  endif ()
endforeach()
bext_run_binary_clear("${binary_cleanup_paths}")
bext_run_rpath_update("${rpath_paths}")

file(WRITE "${BEXT_MANIFEST}.tmp" "{\n")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"schema\": 1,\n")
bext_json_escape(platform "${BEXT_SYSTEM_NAME}")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"platform\": \"${platform}\",\n")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"install_root\": \"install\",\n")
file(APPEND "${BEXT_MANIFEST}.tmp" "  \"generated_by\": \"bext\",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "rpath" rpath_files)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "binary" binary_files)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "cmake" cmake_files)
file(APPEND "${BEXT_MANIFEST}.tmp" ",\n")
bext_write_json_array("${BEXT_MANIFEST}.tmp" "text" plain_text_files)
file(APPEND "${BEXT_MANIFEST}.tmp" "\n}\n")
file(RENAME "${BEXT_MANIFEST}.tmp" "${BEXT_MANIFEST}")

file(TOUCH "${BEXT_MANIFEST}")
message(STATUS "Generated bext install manifest: ${BEXT_MANIFEST}")
