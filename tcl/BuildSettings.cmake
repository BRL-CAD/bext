# Compatibility floors differ from the versions shipped in the Tcl tree.
set(TCL_ENABLE_TK ON CACHE BOOL "enable tk")
option(BEXT_TCL_ENABLE_DOCS "Build and install manuals for bundled Tcl/Tk packages" OFF)
set(BEXT_ITCL_MIN_VERSION "4.3.0")
set(BEXT_ITCL_BUNDLED_VERSION "4.3.7")
set(BEXT_ITCL_BUNDLED_SOURCE_DIR
  "${CMAKE_CURRENT_LIST_DIR}/tcl/pkgs/itcl${BEXT_ITCL_BUNDLED_VERSION}")
