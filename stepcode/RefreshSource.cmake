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

# ExternalProject runs PATCH_COMMAND with DEST_DIR as its current working
# directory.  Removing DEST_DIR itself invalidates that working directory and
# causes the next patch command to fail.  Keep the directory inode, but remove
# all of its contents so overlapping patches and patches which add files are
# always applied to pristine input when PATCH_COMMAND is rerun without the
# local-directory download step.
file(GLOB dest_entries LIST_DIRECTORIES TRUE
  "${dest_abs}/*"
  "${dest_abs}/.[!.]*"
  "${dest_abs}/..?*"
)
if (dest_entries)
  file(REMOVE_RECURSE ${dest_entries})
endif ()
file(COPY "${source_abs}/" DESTINATION "${dest_abs}"
  PATTERN ".git" EXCLUDE
)
