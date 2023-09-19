# Unless we have ENABLE_ALL set, based the building of jpeg on
# the system detection results
if (ENABLE_ALL AND NOT DEFINED ENABLE_JPEG)
  set(ENABLE_JPEG ON)
endif (ENABLE_ALL AND NOT DEFINED ENABLE_JPEG)

if (NOT ENABLE_JPEG)

  find_package(JPEG)

  if (NOT JPEG_FOUND AND NOT DEFINED ENABLE_JPEG)
    set(ENABLE_JPEG "ON" CACHE BOOL "Enable jpeg build")
  endif (NOT JPEG_FOUND AND NOT DEFINED ENABLE_JPEG)

endif (NOT ENABLE_JPEG)
set(ENABLE_JPEG "${ENABLE_JPEG}" CACHE BOOL "Enable jpeg build")

if (ENABLE_JPEG)

  ExternalProject_Add(JPEG_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  if (TARGET PATCH_BLD)
    ExternalProject_Add_StepDependencies(JPEG_BLD configure PATCH_BLD-install)
  endif (TARGET PATCH_BLD)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo/LICENSE.md
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/jpeg.txt
    COPYONLY
    )

endif (ENABLE_JPEG)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

