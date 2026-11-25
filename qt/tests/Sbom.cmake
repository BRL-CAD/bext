function(bext_test_qt_sbom sbom)
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
  bext_test_sbom_package(aggregate "${sbom}" SPDXRef-Package-qt-qt)
  bext_test_sbom_reference("${aggregate}" cpe23Type "cpe:2.3:a:qt:qt:6.12.0:*:*:*:*:*:*:*")
  foreach(suffix IN ITEMS qtbase qtsvg qtbase-build-tools)
    set(id "SPDXRef-Package-qt-qt-${suffix}")
    bext_test_sbom_package(package "${sbom}" "${id}")
    bext_test_sbom_contains("${sbom}" SPDXRef-Package-qt-qt "${id}")
    string(JSON count LENGTH "${package}" externalRefs)
    if(count GREATER 0)
      math(EXPR last "${count} - 1")
      foreach(index RANGE ${last})
        string(JSON type GET "${package}" externalRefs ${index} referenceType)
        if(type STREQUAL "cpe23Type")
          message(FATAL_ERROR "Qt suite CPE must be confined to the aggregate package")
        endif()
      endforeach()
    endif()
  endforeach()
  bext_test_sbom_package(base "${sbom}" SPDXRef-Package-qt-qt-qtbase)
  bext_test_sbom_field("${base}" licenseConcluded LGPL-3.0-only)
  bext_test_sbom_package(emoji "${sbom}" SPDXRef-Package-qt-qt-qtbase-src-3rdparty-emoji-segmenter)
  bext_test_sbom_field("${emoji}" downloadLocation "https://github.com/google/emoji-segmenter/releases/tag/0.4.0")
  bext_test_sbom_field("${emoji}" licenseDeclared Apache-2.0)
  bext_test_sbom_field("${emoji}" licenseConcluded Apache-2.0)
  bext_test_sbom_field("${emoji}" copyrightText "Copyright 2019 Google LLC")
  bext_test_sbom_package(pcre "${sbom}" SPDXRef-Package-qt-qt-qtbase-src-3rdparty-pcre2)
  bext_test_sbom_field("${pcre}" licenseDeclared LicenseRef-BSD-3-Clause-with-PCRE2-Binary-Like-Packages-Exception)
endfunction()
