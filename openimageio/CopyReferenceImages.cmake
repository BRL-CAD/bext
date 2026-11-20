if (NOT DEFINED OPENIMAGEIO_SOURCE_DIR OR NOT IS_DIRECTORY "${OPENIMAGEIO_SOURCE_DIR}")
  message(FATAL_ERROR "OPENIMAGEIO_SOURCE_DIR must name the extracted source tree")
endif ()

include("${CMAKE_CURRENT_LIST_DIR}/ReferenceImages.cmake")
foreach(relative_path IN LISTS OPENIMAGEIO_REFERENCE_IMAGES)
  configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/reference-images/${relative_path}"
    "${OPENIMAGEIO_SOURCE_DIR}/${relative_path}"
    COPYONLY
    )
endforeach()
