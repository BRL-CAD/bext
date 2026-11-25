function(bext_test_opencv_sbom sbom)
  set(opencv_cache "${BEXT_SBOM_OUTPUT}.opencv-cache")
  file(WRITE "${opencv_cache}" [=[
BUILD_ZLIB:BOOL=ON
BUILD_PNG:BOOL=ON
BUILD_TIFF:BOOL=OFF
]=])
  include("${BEXT_SOURCE_DIR}/opencv/SbomSelection.cmake")
  bext_opencv_selected_packages(opencv_selected_packages "${opencv_cache}")
  file(REMOVE "${opencv_cache}")
  foreach(required_opencv_package
      SPDXRef-Package-opencv-opencv
      SPDXRef-Package-opencv-opencv-3rdparty-zlib
      SPDXRef-Package-opencv-opencv-3rdparty-libpng)
    if(NOT required_opencv_package IN_LIST opencv_selected_packages)
      message(FATAL_ERROR "OpenCV SBOM selection omitted ${required_opencv_package}")
    endif()
  endforeach()
  if(SPDXRef-Package-opencv-opencv-3rdparty-libtiff IN_LIST opencv_selected_packages)
    message(FATAL_ERROR "OpenCV SBOM selection retained disabled libtiff")
  endif()
endfunction()
