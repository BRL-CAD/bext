cmake_minimum_required(VERSION 3.19)

if (NOT DEFINED ZLIB_SOURCE_DIR OR NOT IS_DIRECTORY "${ZLIB_SOURCE_DIR}")
  message(FATAL_ERROR "ZLIB_SOURCE_DIR is not a directory")
endif()
if (NOT DEFINED ZLIB_HEADER_ACTION)
  message(FATAL_ERROR "ZLIB_HEADER_ACTION is not defined")
endif()

set(source_header "${ZLIB_SOURCE_DIR}/zlib.h")
set(template_header "${ZLIB_SOURCE_DIR}/zlib.h.in")

# Zlib sources use quoted includes, which prefer zlib.h beside the sources.
# Keep the patched template under a different name so builds use the configured
# header in the binary directory.  Restore it only while applying patches so a
# repeated ExternalProject patch step can still recognize the modified file.
if (ZLIB_HEADER_ACTION STREQUAL "prepare")
  if (NOT EXISTS "${source_header}")
    if (NOT EXISTS "${template_header}")
      message(FATAL_ERROR "Neither the Zlib source nor template header exists")
    endif()
    configure_file("${template_header}" "${source_header}" COPYONLY)
  endif()
elseif (ZLIB_HEADER_ACTION STREQUAL "finalize")
  if (NOT EXISTS "${source_header}")
    message(FATAL_ERROR "The patched Zlib source header does not exist")
  endif()
  configure_file("${source_header}" "${template_header}" COPYONLY)
  file(REMOVE "${source_header}")
else()
  message(FATAL_ERROR
    "Unknown ZLIB_HEADER_ACTION: ${ZLIB_HEADER_ACTION}"
    )
endif()
