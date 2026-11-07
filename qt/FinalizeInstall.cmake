# Exported link interfaces and qmake properties must resolve from the consumed
# prefix so downstream staging can preserve the finalized artifact bytes.
function(_qt_relativize_metadata files replacement)
  foreach(path IN LISTS files)
    file(READ "${path}" content)
    string(REPLACE "${BEXT_INSTALL_ROOT}" "${replacement}" content "${content}")
    file(WRITE "${path}.tmp" "${content}")
    file(COPY_FILE "${path}.tmp" "${path}" ONLY_IF_DIFFERENT)
    file(REMOVE "${path}.tmp")
  endforeach()
endfunction()

file(GLOB_RECURSE qt_target_files
  "${BEXT_INSTALL_ROOT}/${LIB_DIR}/cmake/Qt6*/*Targets*.cmake")
_qt_relativize_metadata("${qt_target_files}" "\${_IMPORT_PREFIX}")
file(GLOB_RECURSE qt_qmake_files "${BEXT_INSTALL_ROOT}/mkspecs/*.pri")
_qt_relativize_metadata("${qt_qmake_files}" "$$[QT_INSTALL_PREFIX]")
