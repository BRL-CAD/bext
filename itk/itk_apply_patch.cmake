if (NOT ITK_SOURCE_DIR OR NOT ITK_PATCH_EXECUTABLE OR NOT ITK_PATCH_FILE)
  message(FATAL_ERROR "Itk patching requires source, patch tool, and patch file paths")
endif ()

# Upstream stores this Windows makefile with CRLF line endings.  The BSD patch
# utility used on some Unix hosts does not normalize them, so normalize the
# staged copy before applying the cross-platform source patch.
set(ITK_WINDOWS_MAKEFILE "${ITK_SOURCE_DIR}/win/makefile.vc")
file(READ "${ITK_WINDOWS_MAKEFILE}" ITK_WINDOWS_MAKEFILE_CONTENTS)
string(REPLACE "\r\n" "\n" ITK_WINDOWS_MAKEFILE_CONTENTS "${ITK_WINDOWS_MAKEFILE_CONTENTS}")
file(WRITE "${ITK_WINDOWS_MAKEFILE}" "${ITK_WINDOWS_MAKEFILE_CONTENTS}")

execute_process(
  COMMAND "${ITK_PATCH_EXECUTABLE}" -E -p1 -i "${ITK_PATCH_FILE}"
  WORKING_DIRECTORY "${ITK_SOURCE_DIR}"
  RESULT_VARIABLE ITK_PATCH_RESULT
  OUTPUT_VARIABLE ITK_PATCH_OUTPUT
  ERROR_VARIABLE ITK_PATCH_ERROR
  )

if (ITK_PATCH_RESULT)
  message(FATAL_ERROR "Itk source patch failed:\n${ITK_PATCH_OUTPUT}${ITK_PATCH_ERROR}")
endif ()

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
