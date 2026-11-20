set(APPLESEED_BOOTSTRAP_PATCH_FILES
  "${CMAKE_CURRENT_LIST_DIR}/bootstrap/0001-dependency-modules.patch"
  "${CMAKE_CURRENT_LIST_DIR}/bootstrap/0002-native-build-targets.patch"
  "${CMAKE_CURRENT_LIST_DIR}/bootstrap/0003-library-api-compatibility.patch"
  "${CMAKE_CURRENT_LIST_DIR}/bootstrap/0004-shader-api-compatibility.patch"
  "${CMAKE_CURRENT_LIST_DIR}/bootstrap/0005-support-files.patch"
  "${CMAKE_CURRENT_LIST_DIR}/bootstrap/0006-platform-and-bundled-libraries.patch"
  "${CMAKE_CURRENT_LIST_DIR}/bootstrap/0007-core-and-developer-fixes.patch"
  )

set(APPLESEED_BOOST_PATCH_FILES
  "${CMAKE_CURRENT_LIST_DIR}/boost/0008-optional-and-unused-wave.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0009-lru-cache-index.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0010-shader-area-index.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0011-filesystem.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0012-atomics.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0013-threads.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0014-chrono.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0015-denoiser-workers.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0016-regex-and-build.patch"
  "${CMAKE_CURRENT_LIST_DIR}/boost/0017-shader-resources.patch"
  )

set(APPLESEED_PATCH_STAGE "CORE" CACHE STRING
  "Appleseed patch stage")
set_property(CACHE APPLESEED_PATCH_STAGE PROPERTY STRINGS CORE)
if(NOT APPLESEED_PATCH_STAGE STREQUAL "CORE")
  message(FATAL_ERROR "APPLESEED_PATCH_STAGE must be CORE")
endif()

set(APPLESEED_PATCH_FILES
  ${APPLESEED_BOOTSTRAP_PATCH_FILES}
  ${APPLESEED_BOOST_PATCH_FILES}
  )
