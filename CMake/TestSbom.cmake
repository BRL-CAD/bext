cmake_minimum_required(VERSION 3.26)

if(NOT DEFINED BEXT_SOURCE_DIR OR NOT DEFINED BEXT_SBOM_OUTPUT)
  message(FATAL_ERROR "BEXT_SOURCE_DIR and BEXT_SBOM_OUTPUT are required")
endif()

set(first "${BEXT_SBOM_OUTPUT}.first")
foreach(output "${first}" "${BEXT_SBOM_OUTPUT}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}"
      -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
      -DBEXT_SBOM_OUTPUT=${output}
      -DBEXT_SBOM_ALLOW_DIRTY=ON
      -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
    RESULT_VARIABLE generation_result
  )
  if(NOT generation_result EQUAL 0)
    message(FATAL_ERROR "SBOM generation failed")
  endif()
endforeach()
file(SHA256 "${first}" first_hash)
file(SHA256 "${BEXT_SBOM_OUTPUT}" second_hash)
file(REMOVE "${first}")
if(NOT first_hash STREQUAL second_hash)
  message(FATAL_ERROR "SBOM generation is not reproducible")
endif()

set(qt_feature_cache "${BEXT_SBOM_OUTPUT}.qt-cache")
file(WRITE "${qt_feature_cache}" [=[
FEATURE_system_zlib:BOOL=OFF
FEATURE_png:BOOL=ON
FEATURE_system_png:BOOL=OFF
FEATURE_jpeg:BOOL=ON
FEATURE_system_jpeg:BOOL=ON
FEATURE_freetype:BOOL=ON
FEATURE_system_freetype:BOOL=OFF
FEATURE_harfbuzz:BOOL=ON
FEATURE_system_harfbuzz:BOOL=OFF
FEATURE_regularexpression:BOOL=ON
FEATURE_system_pcre2:BOOL=OFF
FEATURE_sql_sqlite:BOOL=ON
FEATURE_system_sqlite:BOOL=OFF
FEATURE_textmarkdownreader:BOOL=ON
FEATURE_system_textmarkdownreader:BOOL=OFF
FEATURE_emojisegmenter:BOOL=ON
FEATURE_cborstreamreader:BOOL=ON
FEATURE_cborstreamwriter:BOOL=ON
]=])
include("${BEXT_SOURCE_DIR}/qt/SbomSelection.cmake")
bext_qt_selected_packages(qt_selected_packages "${qt_feature_cache}" OFF)
file(REMOVE "${qt_feature_cache}")
foreach(required_qt_package
    SPDXRef-Package-qt-qt
    SPDXRef-Package-qt-qt-qtbase
    SPDXRef-Package-qt-qt-qtsvg
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-zlib
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-libpng
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-freetype
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-harfbuzz-ng
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-pcre2
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-sqlite
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-md4c
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-emoji-segmenter
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-tinycbor)
  if(NOT required_qt_package IN_LIST qt_selected_packages)
    message(FATAL_ERROR "Qt SBOM selection omitted ${required_qt_package}")
  endif()
endforeach()
if(SPDXRef-Package-qt-qt-qtbase-src-3rdparty-libjpeg IN_LIST qt_selected_packages OR
   SPDXRef-Package-qt-qt-qtbase-build-tools IN_LIST qt_selected_packages)
  message(FATAL_ERROR "Qt SBOM selection retained a system library or excluded SDK tools")
endif()

set(qt_system_cache "${BEXT_SBOM_OUTPUT}.qt-system-cache")
file(WRITE "${qt_system_cache}" [=[
FEATURE_system_zlib:BOOL=ON
FEATURE_png:BOOL=ON
FEATURE_system_png:BOOL=ON
FEATURE_jpeg:BOOL=ON
FEATURE_system_jpeg:BOOL=ON
FEATURE_sql_sqlite:BOOL=ON
FEATURE_system_sqlite:BOOL=ON
]=])
bext_qt_selected_packages(qt_system_packages "${qt_system_cache}" OFF)
file(REMOVE "${qt_system_cache}")
foreach(system_qt_package
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-zlib
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-libpng
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-libjpeg
    SPDXRef-Package-qt-qt-qtbase-src-3rdparty-sqlite)
  if(system_qt_package IN_LIST qt_system_packages)
    message(FATAL_ERROR "Qt SBOM selection retained system package ${system_qt_package}")
  endif()
endforeach()

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

set(assimp_cache "${BEXT_SBOM_OUTPUT}.assimp-cache")
file(WRITE "${assimp_cache}" [=[
ASSIMP_BUILD_MINIZIP:BOOL=ON
ASSIMP_BUILD_3MF_EXPORTER:BOOL=ON
ASSIMP_BUILD_GLTF_IMPORTER:BOOL=ON
RT_FOUND:BOOL=OFF
]=])
include("${BEXT_SOURCE_DIR}/assetimport/SbomSelection.cmake")
bext_assimp_selected_packages(assimp_selected_packages "${assimp_cache}" Windows)
file(REMOVE "${assimp_cache}")
foreach(required_assimp_package
    SPDXRef-Package-assetimport-assimp
    SPDXRef-Package-assetimport-assimp-contrib-poly2tri
    SPDXRef-Package-assetimport-assimp-contrib-openddlparser
    SPDXRef-Package-assetimport-assimp-contrib-rapidjson
    SPDXRef-Package-assetimport-assimp-contrib-utf8cpp
    SPDXRef-Package-assetimport-assimp-contrib-clipper
    SPDXRef-Package-assetimport-assimp-contrib-earcut-hpp
    SPDXRef-Package-assetimport-assimp-contrib-unzip
    SPDXRef-Package-assetimport-assimp-contrib-zip
    SPDXRef-Package-assetimport-assimp-contrib-Open3DGC
    SPDXRef-Package-assetimport-assimp-contrib-stb)
  if(NOT required_assimp_package IN_LIST assimp_selected_packages)
    message(FATAL_ERROR "Assimp SBOM selection omitted ${required_assimp_package}")
  endif()
endforeach()

set(appleseed_cache "${BEXT_SBOM_OUTPUT}.appleseed-cache")
file(WRITE "${appleseed_cache}" [=[
WITH_PYTHON2_BINDINGS:BOOL=OFF
WITH_PYTHON3_BINDINGS:BOOL=OFF
]=])
include("${BEXT_SOURCE_DIR}/appleseed/SbomSelection.cmake")
bext_appleseed_selected_packages(appleseed_selected_packages "${appleseed_cache}")
file(REMOVE "${appleseed_cache}")
foreach(required_appleseed_package
    SPDXRef-Package-appleseed-appleseed
    SPDXRef-Package-appleseed-appleseed-src-thirdparty-bcd
    SPDXRef-Package-appleseed-appleseed-src-thirdparty-murmurhash3)
  if(NOT required_appleseed_package IN_LIST appleseed_selected_packages)
    message(FATAL_ERROR "appleseed SBOM selection omitted ${required_appleseed_package}")
  endif()
endforeach()
if(SPDXRef-Package-appleseed-appleseed-src-thirdparty-glad IN_LIST appleseed_selected_packages)
  message(FATAL_ERROR "appleseed SBOM selection retained build-only GLAD")
endif()

set(dirty_probe "${BEXT_SOURCE_DIR}/sbom-dirty-provenance-test.tmp")
file(WRITE "${dirty_probe}" "first\n")
file(WRITE "${BEXT_SBOM_OUTPUT}" "stale\n")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_SBOM_OUTPUT=${BEXT_SBOM_OUTPUT}
    -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
  RESULT_VARIABLE refused_dirty_result
  ERROR_QUIET
)
if(refused_dirty_result EQUAL 0 OR EXISTS "${BEXT_SBOM_OUTPUT}")
  file(REMOVE "${dirty_probe}")
  message(FATAL_ERROR "Dirty SBOM generation did not reject and remove stale output")
endif()
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_SBOM_OUTPUT=${BEXT_SBOM_OUTPUT}
    -DBEXT_SBOM_ALLOW_DIRTY=ON
    -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
  RESULT_VARIABLE dirty_generation_result
)
file(READ "${BEXT_SBOM_OUTPUT}" first_dirty_sbom)
string(JSON first_dirty_namespace GET "${first_dirty_sbom}" documentNamespace)
file(WRITE "${dirty_probe}" "second\n")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_SBOM_OUTPUT=${BEXT_SBOM_OUTPUT}
    -DBEXT_SBOM_ALLOW_DIRTY=ON
    -P ${BEXT_SOURCE_DIR}/CMake/GenerateSbom.cmake
  RESULT_VARIABLE changed_dirty_generation_result
)
file(READ "${BEXT_SBOM_OUTPUT}" second_dirty_sbom)
string(JSON second_dirty_namespace GET "${second_dirty_sbom}" documentNamespace)
file(REMOVE "${dirty_probe}")
if(NOT dirty_generation_result EQUAL 0 OR NOT changed_dirty_generation_result EQUAL 0)
  message(FATAL_ERROR "Dirty SBOM generation failed")
endif()
if(first_dirty_namespace STREQUAL second_dirty_namespace)
  message(FATAL_ERROR "Dirty source content did not change SBOM provenance")
endif()

set(BEXT_SBOM_INPUT "${BEXT_SBOM_OUTPUT}")
include("${BEXT_SOURCE_DIR}/CMake/ValidateSbom.cmake")
file(READ "${BEXT_SBOM_OUTPUT}" sbom)
string(JSON package_count LENGTH "${sbom}" packages)
math(EXPR package_last "${package_count} - 1")
set(qt_base_checked FALSE)
set(qt_attribution_checked FALSE)
set(qt_custom_license_checked FALSE)
set(revision_purl_checked FALSE)
set(subpath_purl_checked FALSE)
set(copyright_text_checked FALSE)
set(public_domain_copyright_checked FALSE)
set(libpng_cpe_checked FALSE)
set(libtiff_cpe_checked FALSE)
set(zlib_product_cpe_checked FALSE)
set(qt_aggregate_cpe_checked FALSE)
set(qt_children_without_cpe TRUE)
set(qt_aggregate_id "")
set(qt_base_id "")
set(qt_svg_id "")
set(qt_tools_id "")
set(sqlite_version "")
set(tcl_sqlite_version "")
foreach(index RANGE ${package_last})
  string(JSON package_name GET "${sbom}" packages ${index} name)
  string(JSON package_id GET "${sbom}" packages ${index} SPDXID)
  string(JSON external_ref_count LENGTH "${sbom}" packages ${index} externalRefs)
  if(external_ref_count GREATER 0)
    math(EXPR external_ref_last "${external_ref_count} - 1")
    foreach(ref_index RANGE ${external_ref_last})
      string(JSON reference_type GET "${sbom}" packages ${index} externalRefs ${ref_index} referenceType)
      string(JSON reference_locator GET "${sbom}" packages ${index} externalRefs ${ref_index} referenceLocator)
      if(reference_type STREQUAL "cpe23Type" AND reference_locator STREQUAL "cpe:2.3:a:libpng:libpng:1.6.58:*:*:*:*:*:*:*")
        set(libpng_cpe_checked TRUE)
      elseif(reference_type STREQUAL "cpe23Type" AND reference_locator STREQUAL "cpe:2.3:a:libtiff:libtiff:4.7.2:-:*:*:*:*:*:*")
        set(libtiff_cpe_checked TRUE)
      elseif(package_id STREQUAL "SPDXRef-Package-zlib-zlib" AND reference_type STREQUAL "cpe23Type" AND reference_locator STREQUAL "cpe:2.3:a:zlib:zlib:1.4:*:*:*:*:*:*:*")
        set(zlib_product_cpe_checked TRUE)
      elseif(package_name STREQUAL "Qt source aggregate" AND reference_type STREQUAL "cpe23Type" AND reference_locator STREQUAL "cpe:2.3:a:qt:qt:6.12.0:*:*:*:*:*:*:*")
        set(qt_aggregate_cpe_checked TRUE)
      elseif(package_name MATCHES "^Qt (Base|SVG)" AND reference_type STREQUAL "cpe23Type")
        set(qt_children_without_cpe FALSE)
      elseif(package_name STREQUAL "appleseed" AND reference_type STREQUAL "purl")
        string(JSON package_version GET "${sbom}" packages ${index} versionInfo)
        if(reference_locator STREQUAL "pkg:github/BRL-CAD/appleseed@${package_version}")
          set(revision_purl_checked TRUE)
        endif()
      elseif(package_name STREQUAL "Bayesian Collaborative Denoising" AND reference_type STREQUAL "purl" AND
             reference_locator MATCHES "^pkg:github/BRL-CAD/appleseed@[0-9a-f]+#src/thirdparty/bcd$")
        set(subpath_purl_checked TRUE)
      endif()
    endforeach()
  endif()
  if(package_name STREQUAL "Qt Base")
    set(qt_base_id "${package_id}")
    string(JSON license_concluded GET "${sbom}" packages ${index} licenseConcluded)
    if(NOT license_concluded STREQUAL "LGPL-3.0-only")
      message(FATAL_ERROR "Qt Base licenseConcluded was not preserved")
    endif()
    set(qt_base_checked TRUE)
  elseif(package_name STREQUAL "Qt SVG")
    set(qt_svg_id "${package_id}")
  elseif(package_name STREQUAL "Qt Base build tools")
    set(qt_tools_id "${package_id}")
  elseif(package_name STREQUAL "Qt source aggregate")
    set(qt_aggregate_id "${package_id}")
  elseif(package_name STREQUAL "Emoji Segmenter")
    string(JSON download_location GET "${sbom}" packages ${index} downloadLocation)
    string(JSON license_declared GET "${sbom}" packages ${index} licenseDeclared)
    string(JSON license_concluded GET "${sbom}" packages ${index} licenseConcluded)
    string(JSON copyright_text GET "${sbom}" packages ${index} copyrightText)
    if(download_location STREQUAL "https://github.com/google/emoji-segmenter/releases/tag/0.4.0" AND
       license_declared STREQUAL "Apache-2.0" AND
       license_concluded STREQUAL "Apache-2.0" AND
       copyright_text STREQUAL "Copyright 2019 Google LLC")
      set(qt_attribution_checked TRUE)
    endif()
  elseif(package_name STREQUAL "PCRE2")
    string(JSON license_declared GET "${sbom}" packages ${index} licenseDeclared)
    if(license_declared STREQUAL "LicenseRef-BSD-3-Clause-with-PCRE2-Binary-Like-Packages-Exception")
      set(qt_custom_license_checked TRUE)
    endif()
  elseif(package_name STREQUAL "zlib")
    string(JSON copyright_text GET "${sbom}" packages ${index} copyrightText)
    if(copyright_text STREQUAL "Copyright (C) 1995-2026 Jean-loup Gailly and Mark Adler")
      set(copyright_text_checked TRUE)
    endif()
  elseif(package_name STREQUAL "sqlite3")
    string(JSON sqlite_version GET "${sbom}" packages ${index} versionInfo)
    string(JSON copyright_text GET "${sbom}" packages ${index} copyrightText)
    if(copyright_text STREQUAL "NONE")
      set(public_domain_copyright_checked TRUE)
    endif()
  elseif(package_name STREQUAL "SQLite Tcl extension")
    string(JSON tcl_sqlite_version GET "${sbom}" packages ${index} versionInfo)
  endif()
endforeach()
if(NOT sqlite_version OR NOT tcl_sqlite_version STREQUAL sqlite_version)
  message(FATAL_ERROR "Tcl's copied SQLite engine must match the maintained SQLite version")
endif()
set(qt_base_contained FALSE)
set(qt_svg_contained FALSE)
set(qt_tools_contained FALSE)
string(JSON relationship_count LENGTH "${sbom}" relationships)
math(EXPR relationship_last "${relationship_count} - 1")
foreach(index RANGE ${relationship_last})
  string(JSON relationship_type GET "${sbom}" relationships ${index} relationshipType)
  string(JSON relationship_source GET "${sbom}" relationships ${index} spdxElementId)
  string(JSON relationship_target GET "${sbom}" relationships ${index} relatedSpdxElement)
  if(relationship_type STREQUAL "CONTAINS" AND relationship_source STREQUAL qt_aggregate_id)
    if(relationship_target STREQUAL qt_base_id)
      set(qt_base_contained TRUE)
    elseif(relationship_target STREQUAL qt_svg_id)
      set(qt_svg_contained TRUE)
    elseif(relationship_target STREQUAL qt_tools_id)
      set(qt_tools_contained TRUE)
    endif()
  endif()
endforeach()
if(NOT qt_base_checked)
  message(FATAL_ERROR "Qt Base package was not generated")
endif()
if(NOT qt_attribution_checked OR NOT qt_custom_license_checked)
  message(FATAL_ERROR "Qt third-party attribution metadata was not preserved")
endif()
if(NOT revision_purl_checked)
  message(FATAL_ERROR "Revision-derived PURL was not generated")
endif()
if(NOT subpath_purl_checked)
  message(FATAL_ERROR "Revision-derived subpath PURL was not generated")
endif()
if(NOT copyright_text_checked)
  message(FATAL_ERROR "Reviewed copyright text was not generated")
endif()
if(NOT public_domain_copyright_checked)
  message(FATAL_ERROR "Public-domain copyright assertion was not generated")
endif()
if(NOT libpng_cpe_checked OR NOT libtiff_cpe_checked)
  message(FATAL_ERROR "Reviewed CPE assertions were not generated")
endif()
if(NOT zlib_product_cpe_checked)
  message(FATAL_ERROR "Established NVD product CPE was not generated")
endif()
if(NOT qt_aggregate_cpe_checked OR NOT qt_children_without_cpe)
  message(FATAL_ERROR "Qt suite CPE was not confined to the aggregate package")
endif()
if(NOT qt_base_contained OR NOT qt_svg_contained OR NOT qt_tools_contained)
  message(FATAL_ERROR "Qt aggregate does not contain every represented Qt component")
endif()

set(metadata_report "${BEXT_SBOM_OUTPUT}.metadata.md")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    -DBEXT_SOURCE_DIR=${BEXT_SOURCE_DIR}
    -DBEXT_REPORT_OUTPUT=${metadata_report}
    -P ${BEXT_SOURCE_DIR}/CMake/ReportSbomMetadata.cmake
  RESULT_VARIABLE metadata_report_result
)
if(NOT metadata_report_result EQUAL 0)
  message(FATAL_ERROR "SBOM metadata report generation failed")
endif()
file(READ "${metadata_report}" metadata_report_text)
file(REMOVE "${metadata_report}")
foreach(required_heading
    "PURL review queue"
    "Declared license review queue"
    "Concluded license review queue"
    "Copyright review queue"
    "Upstream location review queue"
    "CPE review queue")
  if(NOT metadata_report_text MATCHES "## ${required_heading}")
    message(FATAL_ERROR "SBOM metadata report omitted ${required_heading}")
  endif()
endforeach()
