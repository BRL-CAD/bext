function(bext_test_gdal_sbom sbom)
  set(gdal_cache "${BEXT_SBOM_OUTPUT}.gdal-cache")
  file(WRITE "${gdal_cache}" [=[
GDAL_USE_GEOTIFF_INTERNAL:BOOL=ON
GDAL_USE_GIF_INTERNAL:BOOL=ON
GDAL_USE_JPEG_INTERNAL:BOOL=ON
GDAL_USE_JSONC_INTERNAL:BOOL=ON
GDAL_USE_LERC_INTERNAL:BOOL=ON
GDAL_USE_OPENCAD_INTERNAL:BOOL=ON
GDAL_USE_QHULL_INTERNAL:BOOL=ON
GDAL_USE_SHAPELIB_INTERNAL:BOOL=ON
GDAL_ENABLE_DRIVER_GTIFF:BOOL=ON
GDAL_ENABLE_DRIVER_GIF:BOOL=ON
GDAL_ENABLE_DRIVER_JPEG:BOOL=ON
OGR_ENABLE_DRIVER_GEOJSON:BOOL=ON
OGR_ENABLE_DRIVER_CAD:BOOL=ON
OGR_ENABLE_DRIVER_SHAPE:BOOL=ON
GDAL_ENABLE_DRIVER_NITF:BOOL=OFF
GDAL_ENABLE_DRIVER_VRT:BOOL=ON
]=])
  include("${BEXT_SOURCE_DIR}/gdal/SbomSelection.cmake")
  bext_gdal_selected_packages(gdal_selected_packages "${gdal_cache}")
  file(REMOVE "${gdal_cache}")
  foreach(required_gdal_package
      SPDXRef-Package-gdal-gdal
      SPDXRef-Package-gdal-gdal-frmts-gtiff-libgeotiff
      SPDXRef-Package-gdal-gdal-frmts-gif-giflib
      SPDXRef-Package-gdal-gdal-frmts-jpeg-libjpeg
      SPDXRef-Package-gdal-gdal-ogr-ogrsf-frmts-geojson-libjson
      SPDXRef-Package-gdal-gdal-third-party-LercLib
      SPDXRef-Package-gdal-gdal-ogr-ogrsf-frmts-cad-libopencad
      SPDXRef-Package-gdal-gdal-alg-internal-libqhull
      SPDXRef-Package-gdal-gdal-ogr-ogrsf-frmts-shape-shapelib
      SPDXRef-Package-gdal-gdal-third-party-fast-float
      SPDXRef-Package-gdal-gdal-third-party-libdivide)
    if(NOT required_gdal_package IN_LIST gdal_selected_packages)
      message(FATAL_ERROR "GDAL SBOM selection omitted ${required_gdal_package}")
    endif()
  endforeach()

  file(WRITE "${gdal_cache}" [=[
GDAL_USE_JPEG_INTERNAL:BOOL=OFF
GDAL_ENABLE_DRIVER_JPEG:BOOL=ON
]=])
  bext_gdal_selected_packages(gdal_system_packages "${gdal_cache}")
  file(REMOVE "${gdal_cache}")
  if(SPDXRef-Package-gdal-gdal-frmts-jpeg-libjpeg IN_LIST gdal_system_packages)
    message(FATAL_ERROR "GDAL SBOM selection retained system libjpeg")
  endif()
endfunction()
