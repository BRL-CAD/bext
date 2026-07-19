if (NOT DEFINED SOURCE_DIR OR NOT IS_DIRECTORY "${SOURCE_DIR}")
  message(FATAL_ERROR "SOURCE_DIR is not a directory: ${SOURCE_DIR}")
endif ()

if (NOT DEFINED DEST_DIR OR DEST_DIR STREQUAL "")
  message(FATAL_ERROR "DEST_DIR is not defined")
endif ()

cmake_path(ABSOLUTE_PATH SOURCE_DIR NORMALIZE OUTPUT_VARIABLE source_abs)
cmake_path(ABSOLUTE_PATH DEST_DIR NORMALIZE OUTPUT_VARIABLE dest_abs)
if (source_abs STREQUAL dest_abs)
  message(FATAL_ERROR "Refusing to refresh a source directory from itself")
endif ()

cmake_path(GET dest_abs FILENAME dest_name)
if (NOT dest_name STREQUAL "STEPCODE_BLD")
  message(FATAL_ERROR "Refusing to remove unexpected destination: ${dest_abs}")
endif ()

# ExternalProject may rerun PATCH_COMMAND without rerunning its local-directory
# download step.  Recreate the generated source copy so overlapping patches and
# patches which add files are always applied to pristine input.
file(REMOVE_RECURSE "${dest_abs}")
file(MAKE_DIRECTORY "${dest_abs}")
file(COPY "${source_abs}/" DESTINATION "${dest_abs}"
  PATTERN ".git" EXCLUDE
)
