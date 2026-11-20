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

set(APPLESEED_ART_PATCH_FILES
  "${CMAKE_CURRENT_LIST_DIR}/art/0018-procedural-surfaces.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0019-osl-input-contracts.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0020-bump-and-texture-nodes.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0021-struetype.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0022-ideal-glass.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0023-closure-mixtures.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0024-coat-closures.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0025-panorama-and-image-helpers.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0026-cancellation.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0027-npr-contours.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0028-primary-media.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0029-boundary-ownership.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0030-physical-ray-origins.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0031-osl-object-data.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0032-emitter-surfaces.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0033-emitter-geometry.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0034-weighted-emitters.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0035-emitter-mis.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0036-participating-media.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0037-image-output.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0038-volume-numerics.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0039-volume-environment.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0040-directional-emission.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0041-coincident-covers.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0042-selected-normal-derivatives.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0043-ggx-sampling.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0044-surface-frame-derivatives.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0045-beckmann-and-normal-incidence.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0046-standard-microfacet-reflection.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0047-closure-ior-context.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0048-standard-microfacet-transmission.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0049-emission-range.patch"
  "${CMAKE_CURRENT_LIST_DIR}/art/0050-height-curvature.patch"
  )

set(APPLESEED_PATCH_STAGE "ART" CACHE STRING
  "Appleseed patch stage: CORE removes Boost; ART adds renderer integration features")
set_property(CACHE APPLESEED_PATCH_STAGE PROPERTY STRINGS CORE ART)

set(APPLESEED_PATCH_FILES
  ${APPLESEED_BOOTSTRAP_PATCH_FILES}
  ${APPLESEED_BOOST_PATCH_FILES}
  )
if(APPLESEED_PATCH_STAGE STREQUAL "ART")
  list(APPEND APPLESEED_PATCH_FILES ${APPLESEED_ART_PATCH_FILES})
elseif(NOT APPLESEED_PATCH_STAGE STREQUAL "CORE")
  message(FATAL_ERROR "APPLESEED_PATCH_STAGE must be CORE or ART")
endif()
