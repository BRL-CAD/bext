if (NOT EXISTS "${TCL_SOURCE_DIR}/win/Makefile.in")
  message(FATAL_ERROR "TCL_SOURCE_DIR must name the staged Tcl source tree")
endif ()
# Vendor imports omit ignored manifest.uuid files.  These source copies are
# not Git checkouts; do not let package makefiles query the outer repository.
file(GLOB packages LIST_DIRECTORIES true "${TCL_SOURCE_DIR}/pkgs/*")
list(APPEND packages "${TCL_SOURCE_DIR}")
foreach(package IN LISTS packages)
  if (IS_DIRECTORY "${package}" AND NOT EXISTS "${package}/manifest.uuid")
    configure_file("${CMAKE_CURRENT_LIST_DIR}/package_manifest.uuid"
      "${package}/manifest.uuid" COPYONLY)
  endif ()
endforeach ()
