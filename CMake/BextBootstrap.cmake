set(bext_root "${CMAKE_CURRENT_LIST_DIR}/..")
get_filename_component(bext_root "${bext_root}" ABSOLUTE)

if (NOT DEFINED PROFILE)
  message(FATAL_ERROR "Set PROFILE to one of: auto, bundled, minimal, everything")
endif (NOT DEFINED PROFILE)

string(TOLOWER "${PROFILE}" profile)
set(active_groups)

if (profile STREQUAL "auto" OR profile STREQUAL "bundled")
  set(active_groups BRLCAD BRLCAD_EXTRA GDAL QT TCL)
elseif (profile STREQUAL "minimal")
  set(active_groups BRLCAD)
elseif (profile STREQUAL "everything")
  set(active_groups APPLESEED BRLCAD BRLCAD_EXTRA GDAL OSPRAY QT TCL)
else ()
  message(FATAL_ERROR "Unknown PROFILE \"${PROFILE}\". Expected: auto, bundled, minimal, everything")
endif ()

find_program(GIT_EXECUTABLE git)
if (NOT GIT_EXECUTABLE)
  message(FATAL_ERROR "Unable to find git executable required for bootstrap")
endif (NOT GIT_EXECUTABLE)

file(STRINGS "${bext_root}/CMakeLists.txt" project_lines REGEX "add_project\\(")

set(project_paths)
foreach(line ${project_lines})
  string(STRIP "${line}" stripped_line)
  if (stripped_line MATCHES "^#")
    continue()
  endif (stripped_line MATCHES "^#")

  if (NOT stripped_line MATCHES "^add_project\\(([A-Za-z0-9_+.-]+)")
    continue()
  endif (NOT stripped_line MATCHES "^add_project\\(([A-Za-z0-9_+.-]+)")

  set(project_name "${CMAKE_MATCH_1}")
  set(include_project FALSE)

  if (stripped_line MATCHES "GROUPS \"([^\"]+)\"")
    set(project_groups "${CMAKE_MATCH_1}")
    string(REPLACE ";" ";" project_groups "${project_groups}")
    foreach(group ${project_groups})
      list(FIND active_groups "${group}" group_index)
      if (NOT group_index EQUAL -1)
        set(include_project TRUE)
        break()
      endif (NOT group_index EQUAL -1)
    endforeach(group ${project_groups})
  else ()
    set(include_project TRUE)
  endif ()

  if (include_project)
    list(APPEND project_paths "${project_name}")
  endif (include_project)
endforeach(line ${project_lines})

list(REMOVE_DUPLICATES project_paths)
list(SORT project_paths)

string(REPLACE ";" ", " active_groups_str "${active_groups}")
string(REPLACE ";" ", " project_paths_str "${project_paths}")

message(STATUS "bext bootstrap profile: ${profile}")
message(STATUS "active USE_* groups: ${active_groups_str}")
message(STATUS "project submodules: ${project_paths_str}")

if (LIST_ONLY)
  message(STATUS "LIST_ONLY is ON, skipping git submodule update")
  return()
endif (LIST_ONLY)

set(git_args submodule update --init --recursive --jobs 8)
if (GIT_SHALLOW_CLONE)
  list(APPEND git_args --recommend-shallow)
endif (GIT_SHALLOW_CLONE)
list(APPEND git_args -- ${project_paths})

execute_process(
  COMMAND ${GIT_EXECUTABLE} ${git_args}
  WORKING_DIRECTORY ${bext_root}
  COMMAND_ERROR_IS_FATAL ANY
)

message(STATUS "Bootstrap complete for profile ${profile}")
