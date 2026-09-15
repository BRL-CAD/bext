if (NOT ITK_SOURCE_DIR OR NOT ITK_PATCH_EXECUTABLE OR
    NOT ITK_PATCH_CHECK_OPTION OR NOT ITK_PATCH_REJECT_DIR OR
    NOT ITK_PATCH_FILE OR NOT ITK_INSTALL_PATCH_FILE)
  message(FATAL_ERROR
    "Itk patching requires source, patch tool, check option, reject "
    "directory, and patch file paths")
endif ()

# Upstream stores this Windows makefile with CRLF line endings.  The BSD patch
# utility used on some Unix hosts does not normalize them, so normalize the
# staged copy before applying the cross-platform source patches.
set(ITK_WINDOWS_MAKEFILE "${ITK_SOURCE_DIR}/win/makefile.vc")
file(READ "${ITK_WINDOWS_MAKEFILE}" ITK_WINDOWS_MAKEFILE_CONTENTS)
string(REPLACE "\r\n" "\n" ITK_WINDOWS_MAKEFILE_CONTENTS "${ITK_WINDOWS_MAKEFILE_CONTENTS}")
file(WRITE "${ITK_WINDOWS_MAKEFILE}" "${ITK_WINDOWS_MAKEFILE_CONTENTS}")

set(ITK_PATCH_WRAPPER "${CMAKE_CURRENT_LIST_DIR}/../CMake/PatchWrapper.cmake")
set(ITK_PATCH_FILES
  "${ITK_PATCH_FILE}"
  "${ITK_INSTALL_PATCH_FILE}"
  )
foreach (ITK_CURRENT_PATCH_FILE IN LISTS ITK_PATCH_FILES)
  execute_process(
    COMMAND "${CMAKE_COMMAND}"
      "-DBEXT_PATCH_NATIVE_EXECUTABLE=${ITK_PATCH_EXECUTABLE}"
      "-DBEXT_PATCH_CHECK_OPTION=${ITK_PATCH_CHECK_OPTION}"
      "-DBEXT_PATCH_REJECT_DIR=${ITK_PATCH_REJECT_DIR}"
      -P "${ITK_PATCH_WRAPPER}" -- -E -p1 -N -i "${ITK_CURRENT_PATCH_FILE}"
    WORKING_DIRECTORY "${ITK_SOURCE_DIR}"
    RESULT_VARIABLE ITK_PATCH_RESULT
    OUTPUT_VARIABLE ITK_PATCH_OUTPUT
    ERROR_VARIABLE ITK_PATCH_ERROR
    )

  if (ITK_PATCH_RESULT)
    message(FATAL_ERROR
      "Itk source patch failed for ${ITK_CURRENT_PATCH_FILE}:\n"
      "${ITK_PATCH_OUTPUT}${ITK_PATCH_ERROR}"
      )
  endif ()
endforeach ()

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
