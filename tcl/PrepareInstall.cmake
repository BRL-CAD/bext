# TEA configuration files expose producer paths and are needed only while
# building the toolkit stack. Remove them from the finalized bundle.
file(GLOB_RECURSE build_config_files
  "${BEXT_INSTALL_ROOT}/*/tclConfig.sh"
  "${BEXT_INSTALL_ROOT}/*/itclConfig.sh"
  "${BEXT_INSTALL_ROOT}/*/tdbcConfig.sh")
if(build_config_files)
  file(REMOVE ${build_config_files})
endif()
