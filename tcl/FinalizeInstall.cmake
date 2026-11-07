# Tcl's ELF build does not always set a SONAME. Supply it before publishing
# artifact hashes so consumers can link and stage the same finalized library.
foreach(relative IN LISTS installed_files)
  if(NOT relative MATCHES "(^|/)libtcl[^/]*[.]so([.][0-9]+)*$" OR
     IS_SYMLINK "${BEXT_INSTALL_ROOT}/${relative}")
    continue()
  endif()
  if(NOT BEXT_PLIEF)
    message(FATAL_ERROR "Tcl ELF finalization needs plief or patchelf; enable the PLIEF build")
  endif()
  set(path "${BEXT_INSTALL_ROOT}/${relative}")
  execute_process(COMMAND "${BEXT_PLIEF}" --print-soname "${path}"
    RESULT_VARIABLE result OUTPUT_VARIABLE soname ERROR_VARIABLE error
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Unable to read the Tcl SONAME: ${error}")
  endif()
  if(soname STREQUAL "")
    get_filename_component(soname "${path}" NAME)
    execute_process(COMMAND "${BEXT_PLIEF}" --set-soname "${soname}" "${path}"
      RESULT_VARIABLE result ERROR_VARIABLE error)
    if(NOT result EQUAL 0)
      message(FATAL_ERROR "Unable to set the Tcl SONAME: ${error}")
    endif()
  endif()
endforeach()
