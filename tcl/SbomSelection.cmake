function(bext_tcl_selected_packages output cache_file)
  if(NOT EXISTS "${cache_file}")
    message(FATAL_ERROR "Tcl package selection requires its configure cache")
  endif()
  set(packages
    SPDXRef-Package-tcl-tcl
    SPDXRef-Package-tcl-tcl-libtommath
    SPDXRef-Package-tcl-tcl-pkgs-itcl4.3.7
    SPDXRef-Package-tcl-tcl-pkgs-thread2.8.13)
  file(STRINGS "${cache_file}" database_option
    REGEX "^BEXT_TCL_ENABLE_DATABASE_PACKAGES:BOOL=")
  if(NOT database_option)
    message(FATAL_ERROR "Tcl database-package selection is missing from its cache")
  endif()
  string(REGEX REPLACE "^[^=]*=" "" enabled "${database_option}")
  if(enabled)
    foreach(package IN ITEMS sqlite3.53.0 tdbc1.1.13 tdbcmysql1.1.13
        tdbcodbc1.1.13 tdbcpostgres1.1.13 tdbcsqlite3-1.1.13)
      list(APPEND packages "SPDXRef-Package-tcl-tcl-pkgs-${package}")
    endforeach()
  endif()
  set(${output} "${packages}" PARENT_SCOPE)
endfunction()
