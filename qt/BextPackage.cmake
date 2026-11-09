bext_package(qt OUTPUT install GROUPS QT
  LEGAL_NAMES
    qtbase
    qtsvg
)

# Configure-time ownership only needs the package declaration above. Keep
# optional Qt sources out of configurations that do not select bundled Qt.
if(BEXT_PACKAGE_BUILD_ONLY)
  return()
endif()

bext_sbom_component("qt/qt"
  NAME "Qt source aggregate"
  VERSION "6.12.0"
  UPSTREAM_URL "https://www.qt.io/"
  PURL_BASE "pkg:github/BRL-CAD/qt"
  CPE "cpe:2.3:a:qt:qt:6.12.0:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:qt:qt:5.5.1:*:*:*:*:*:*:*"
  CPE_COMMENT "Suite-level NVD identity for vulnerability triage only. Confirm each match against Qt advisories for the contained qtbase and qtsvg modules."
  LICENSE "LicenseRef-Qt-Source-REUSE-Aggregate"
  LICENSE_CONCLUDED "LicenseRef-Qt-Source-REUSE-Aggregate"
  LICENSE_NAME "Qt source REUSE aggregate"
  LICENSE_FILE "@/qt/licenses/qt-source-reuse.txt"
  LICENSE_SHA256 "3905736008a7b3e9bd0ab48503e3c371cc6c3ca2d380eb869353f4637b5f951c"
  REVIEWED_REVISION "3178765365af3497b0fe60d6cb0e1012027d9b75"
  LICENSE_COMMENT "Source container preserving the complete qtbase and qtsvg REUSE identifier sets and their source-level alternatives. Contained packages record bext's selected output licenses."
  PURPOSE "CONTAINER"
)

bext_sbom_subcomponent("qt/qt" "qtbase"
  NAME "Qt Base"
  VERSION "6.12.0"
  UPSTREAM_URL "https://download.qt.io/official_releases/qt/6.12/6.12.0/submodules/"
  PURL "pkg:generic/qt/qtbase@6.12.0?download_url=https%3A%2F%2Fdownload.qt.io%2Fofficial_releases%2Fqt%2F6.12%2F6.12.0%2Fsubmodules%2Fqtbase-everywhere-src-6.12.0.tar.xz"
  LICENSE "LGPL-3.0-only"
  LICENSE_CONCLUDED "LGPL-3.0-only"
  LICENSE_FILE "qtbase/LICENSES/LGPL-3.0-only.txt"
  LICENSE_SHA256 "da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768"
  LICENSE_COMMENT "bext selects Qt Base's LGPL-3.0-only option. Tests and examples are disabled, while essential GPL-with-exception code generators are represented separately."
  PURPOSE "FRAMEWORK"
  SCOPE "RUNTIME"
)

bext_sbom_subcomponent("qt/qt" "qtsvg"
  NAME "Qt SVG"
  VERSION "6.12.0"
  UPSTREAM_URL "https://download.qt.io/official_releases/qt/6.12/6.12.0/submodules/"
  PURL "pkg:generic/qt/qtsvg@6.12.0?download_url=https%3A%2F%2Fdownload.qt.io%2Fofficial_releases%2Fqt%2F6.12%2F6.12.0%2Fsubmodules%2Fqtsvg-everywhere-src-6.12.0.tar.xz"
  LICENSE "LGPL-3.0-only"
  LICENSE_CONCLUDED "LGPL-3.0-only"
  LICENSE_FILE "qtsvg/LICENSES/LGPL-3.0-only.txt"
  LICENSE_SHA256 "da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768"
  LICENSE_COMMENT "bext selects Qt SVG's LGPL-3.0-only option and excludes its tests and examples."
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)

bext_sbom_subcomponent("qt/qt" "qtbase-build-tools"
  NAME "Qt Base build tools"
  VERSION "6.12.0"
  UPSTREAM_URL "https://download.qt.io/official_releases/qt/6.12/6.12.0/submodules/"
  PURL "pkg:generic/qt/qtbase@6.12.0?download_url=https%3A%2F%2Fdownload.qt.io%2Fofficial_releases%2Fqt%2F6.12%2F6.12.0%2Fsubmodules%2Fqtbase-everywhere-src-6.12.0.tar.xz"
  LICENSE "GPL-3.0-only WITH Qt-GPL-exception-1.0"
  LICENSE_CONCLUDED "GPL-3.0-only WITH Qt-GPL-exception-1.0"
  LICENSE_FILES
    "qtbase/LICENSES/GPL-3.0-only.txt"
    "qtbase/LICENSES/Qt-GPL-exception-1.0.txt"
  LICENSE_SHA256S
    "8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903"
    "40678d338ce53cd93f8b22b281a2ecbcaa3ee65ce60b25ffb0c462b0530846b2"
  LICENSE_COMMENT "Qt's code-generation and deployment tools, including moc, rcc, and uic, use GPL-3.0-only WITH Qt-GPL-exception-1.0. They are build tools, not linked runtime components."
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)

function(_bext_qt_security_component relative_path)
  set(attribution_file "${BEXT_PACKAGE_DIR}/qt/qtbase/${relative_path}/qt_attribution.json")
  file(READ "${attribution_file}" attribution_json)
  string(JSON root_type TYPE "${attribution_json}")
  if(root_type STREQUAL "ARRAY")
    string(JSON entry_count LENGTH "${attribution_json}")
  else()
    set(entry_count 1)
  endif()

  math(EXPR entry_last "${entry_count} - 1")
  foreach(entry_index RANGE ${entry_last})
    if(root_type STREQUAL "ARRAY")
      string(JSON entry GET "${attribution_json}" ${entry_index})
    else()
      set(entry "${attribution_json}")
    endif()
    string(JSON security_critical ERROR_VARIABLE security_error GET "${entry}" SecurityCritical)
    if(security_error OR NOT security_critical)
      continue()
    endif()

    foreach(field Name Version Homepage)
      string(JSON ${field} GET "${entry}" ${field})
    endforeach()
    string(JSON DownloadLocation GET "${entry}" DownloadLocation)
    string(JSON LicenseId GET "${entry}" LicenseId)
    string(JSON purl_type TYPE "${entry}" PURL)
    if(purl_type STREQUAL "ARRAY")
      string(JSON purl GET "${entry}" PURL 0)
    else()
      string(JSON purl GET "${entry}" PURL)
    endif()
    string(REPLACE "." "-" version_dashed "${Version}")
    string(REPLACE "$<VERSION_DASHED>" "${version_dashed}" purl "${purl}")
    string(REPLACE "$<VERSION>" "${Version}" purl "${purl}")

    set(component_args
      NAME "${Name}"
      VERSION "${Version}"
      UPSTREAM_URL "${Homepage}"
      DOWNLOAD_LOCATION "${DownloadLocation}"
      PURL "${purl}"
      LICENSE "${LicenseId}"
      LICENSE_CONCLUDED "${LicenseId}"
      PURPOSE "LIBRARY"
      SCOPE "RUNTIME"
      REVIEWED_REVISION "3178765365af3497b0fe60d6cb0e1012027d9b75"
    )
    string(JSON copyright_type ERROR_VARIABLE copyright_error TYPE "${entry}" Copyright)
    if(NOT copyright_error)
      if(copyright_type STREQUAL "ARRAY")
        string(JSON copyright_count LENGTH "${entry}" Copyright)
        math(EXPR copyright_last "${copyright_count} - 1")
        set(copyright_text)
        foreach(copyright_index RANGE ${copyright_last})
          string(JSON copyright_line GET "${entry}" Copyright ${copyright_index})
          if(copyright_text)
            string(APPEND copyright_text "\n")
          endif()
          string(APPEND copyright_text "${copyright_line}")
        endforeach()
      else()
        string(JSON copyright_text GET "${entry}" Copyright)
      endif()
      list(APPEND component_args
        COPYRIGHT_TEXT "${copyright_text}"
        COPYRIGHT_REVIEWED_REVISION "3178765365af3497b0fe60d6cb0e1012027d9b75")
    endif()

    if(relative_path STREQUAL "src/3rdparty/emoji-segmenter")
      list(APPEND component_args
        LICENSE_FILE "qtbase/LICENSES/Apache-2.0.txt"
        LICENSE_SHA256 "e3ba223bb1423f0aad8c3dfce0fe3148db48926d41e6fbc3afbbf5ff9e1c89cb")
    elseif(relative_path STREQUAL "src/3rdparty/freetype")
      list(APPEND component_args
        LICENSE_FILE "qtbase/${relative_path}/LICENSE.txt"
        LICENSE_SHA256 "bf543cdda11864477b8d2ca2aa9afc2aaa8f9133461b4d962ed6ec73646256a1")
    elseif(relative_path STREQUAL "src/3rdparty/harfbuzz-ng")
      list(APPEND component_args
        LICENSE_FILE "qtbase/${relative_path}/COPYING"
        LICENSE_SHA256 "ba8f810f2455c2f08e2d56bb49b72f37fcf68f1f4fade38977cfd7372050ad64")
    elseif(relative_path STREQUAL "src/3rdparty/libjpeg")
      list(APPEND component_args
        LICENSE_FILES
          "qtbase/LICENSES/IJG.txt"
          "qtbase/LICENSES/BSD-3-Clause.txt"
        LICENSE_SHA256S
          "1cb448f5e2e6d3aca60943f4eee1a04675628dc0266a074a42bc1560ebc28d61"
          "9f0490f18656c6f2435bd14f603ef0c96434d1825615363dce43abb42ed1dcce")
    elseif(relative_path STREQUAL "src/3rdparty/libpng")
      list(APPEND component_args
        LICENSE_FILE "qtbase/${relative_path}/LICENSE"
        LICENSE_SHA256 "bdb0a645ea18c60507d0368379b1ac5474b92255fcc2d115e07486a7672ba526")
    elseif(relative_path STREQUAL "src/3rdparty/md4c")
      list(APPEND component_args
        LICENSE_FILE "qtbase/${relative_path}/LICENSE.md"
        LICENSE_SHA256 "d30937367d5413e7eaa218b1640b8946ff76fd34d97152f6979fd96169d5d0fc")
    elseif(relative_path STREQUAL "src/3rdparty/pcre2")
      string(JSON LicenseName GET "${entry}" License)
      list(APPEND component_args
        LICENSE_NAME "${LicenseName}"
        LICENSE_FILE "qtbase/${relative_path}/LICENCE.md"
        LICENSE_SHA256 "197d8a73ffee0d6b09adba2f9c677b5f5aede24edf89258a68e48248d010d811")
    elseif(relative_path STREQUAL "src/3rdparty/sqlite")
      list(APPEND component_args
        LICENSE_FILE "qtbase/LICENSES/blessing.txt"
        LICENSE_SHA256 "592db1199aab67aafe4515db9808b420db122083807c5329b2f061951e79acbe")
    elseif(relative_path STREQUAL "src/3rdparty/tinycbor")
      list(APPEND component_args
        LICENSE_FILE "qtbase/${relative_path}/LICENSE"
        LICENSE_SHA256 "3c6ba0b5bfa7830505301ffb336a17b0748e0d61c4d34216e9dc98f10e40395e")
    elseif(relative_path STREQUAL "src/3rdparty/zlib")
      list(APPEND component_args
        LICENSE_FILE "qtbase/${relative_path}/LICENSE"
        LICENSE_SHA256 "d7e3139972874dc8abdbbfce27ec1e6f942b28279dd7d27453630a8b4610e080")
    endif()
    string(JSON qt_cpe ERROR_VARIABLE cpe_error GET "${entry}" CPE)
    if(NOT cpe_error)
      string(JSON cpe_type TYPE "${entry}" CPE)
      if(cpe_type STREQUAL "ARRAY")
        string(JSON qt_cpe GET "${entry}" CPE 0)
      endif()
      string(REPLACE "$<VERSION>" "${Version}" qt_cpe "${qt_cpe}")
      if(relative_path STREQUAL "src/3rdparty/libpng")
        list(APPEND component_args CPE "${qt_cpe}" CPE_STATUS "NVD_EXACT")
      elseif(relative_path STREQUAL "src/3rdparty/zlib")
        list(APPEND component_args CPE "${qt_cpe}" CPE_STATUS "NVD_PRODUCT"
          CPE_PRODUCT_EVIDENCE "cpe:2.3:a:zlib:zlib:0.3:*:*:*:*:*:*:*")
      elseif(relative_path STREQUAL "src/3rdparty/libjpeg")
        list(APPEND component_args CPE "${qt_cpe}" CPE_STATUS "NVD_PRODUCT"
          CPE_PRODUCT_EVIDENCE "cpe:2.3:a:libjpeg-turbo:libjpeg-turbo:0.0.90:*:*:*:*:*:*:*")
      elseif(relative_path STREQUAL "src/3rdparty/sqlite")
        list(APPEND component_args CPE "${qt_cpe}" CPE_STATUS "NVD_PRODUCT"
          CPE_PRODUCT_EVIDENCE "cpe:2.3:a:sqlite:sqlite:3.8.8.3:*:*:*:*:*:*:*")
      endif()
    endif()
    bext_sbom_subcomponent("qt/qt" "qtbase/${relative_path}" ${component_args})
  endforeach()
endfunction()

set(_bext_qt_security_paths
    src/3rdparty/emoji-segmenter
    src/3rdparty/freetype
    src/3rdparty/harfbuzz-ng
    src/3rdparty/libjpeg
    src/3rdparty/libpng
    src/3rdparty/md4c
    src/3rdparty/pcre2
    src/3rdparty/sqlite
    src/3rdparty/tinycbor
    src/3rdparty/zlib)
foreach(_bext_qt_security_path IN LISTS _bext_qt_security_paths)
  _bext_qt_security_component("${_bext_qt_security_path}")
endforeach()

function(_bext_qt_attribution_is_security_critical output attribution_file)
  file(READ "${attribution_file}" attribution_json)
  # Qt permits multiline descriptions in some non-security attribution files.
  # Only parse files that can contribute security-critical packages.
  if(NOT attribution_json MATCHES "\"SecurityCritical\"[ \t\r\n]*:[ \t\r\n]*true")
    set(${output} FALSE PARENT_SCOPE)
    return()
  endif()
  string(JSON root_type TYPE "${attribution_json}")
  if(root_type STREQUAL "ARRAY")
    string(JSON entry_count LENGTH "${attribution_json}")
  else()
    set(entry_count 1)
  endif()
  set(found FALSE)
  math(EXPR entry_last "${entry_count} - 1")
  foreach(entry_index RANGE ${entry_last})
    if(root_type STREQUAL "ARRAY")
      string(JSON entry GET "${attribution_json}" ${entry_index})
    else()
      set(entry "${attribution_json}")
    endif()
    string(JSON security_critical ERROR_VARIABLE security_error GET "${entry}" SecurityCritical)
    if(NOT security_error AND security_critical)
      set(found TRUE)
      break()
    endif()
  endforeach()
  set(${output} "${found}" PARENT_SCOPE)
endfunction()

file(GLOB_RECURSE _bext_qt_attribution_files
  "${BEXT_PACKAGE_DIR}/qt/qtbase/*/qt_attribution.json"
  "${BEXT_PACKAGE_DIR}/qt/qtsvg/*/qt_attribution.json")
foreach(_bext_qt_attribution_file IN LISTS _bext_qt_attribution_files)
  _bext_qt_attribution_is_security_critical(_bext_qt_is_security_critical "${_bext_qt_attribution_file}")
  if(NOT _bext_qt_is_security_critical)
    continue()
  endif()
  file(RELATIVE_PATH _bext_qt_relative "${BEXT_PACKAGE_DIR}/qt/qtbase" "${_bext_qt_attribution_file}")
  get_filename_component(_bext_qt_relative "${_bext_qt_relative}" DIRECTORY)
  list(FIND _bext_qt_security_paths "${_bext_qt_relative}" _bext_qt_security_index)
  if(_bext_qt_security_index EQUAL -1)
    message(FATAL_ERROR
      "Qt marks ${_bext_qt_attribution_file} security-critical, but it has no installed-SBOM feature mapping")
  endif()
endforeach()
