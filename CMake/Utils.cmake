#                     U T I L S . C M A K E
# BRL-CAD
#
# Copyright (c) 2025 United States Government as represented by
# the U.S. Army Research Laboratory.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following
# disclaimer in the documentation and/or other materials provided
# with the distribution.
#
# 3. The name of the author may not be used to endorse or promote
# products derived from this software without specific prior written
# permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
###

include("${CMAKE_CURRENT_LIST_DIR}/BextGit.cmake")

###############################################################################
# It is common for more complex targets to need to key build settings off of
# whether or not their dependencies are being built locally.  These macros are
# used to cut down on boilerplate code
###############################################################################

macro(TargetVars roots)
  foreach(root ${${roots}})
    if (NOT ${root}_ADDED)
      message(FATAL_ERROR "${root} is listed as a dependency but is not yet added - fix project ordering in top level CMakeLists.txt file")
    endif (NOT ${root}_ADDED)
    if (TARGET ${root}_BLD)
      set(${root}_TARGET 1)
      # Also set the TARGET var in the parent scope - may need it in other
      # build logic besides the current directory.
      set(${root}_TARGET 1 PARENT_SCOPE)
    endif (TARGET ${root}_BLD)
  endforeach(root ${${roots}})
endmacro(TargetVars root)


###
# Loads dependencies from an in-src file named same as containing
# directory with .deps suffix.  Dependencies are added to the
# corresponding ${proot}_DEPENDS variable.
###
macro(RegisterDeps proot)
  get_filename_component(dirname ${CMAKE_CURRENT_SOURCE_DIR} NAME)
  if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${dirname}.deps")
    message(FATAL_ERROR "No ${dirname}.deps file found in ${CMAKE_CURRENT_SOURCE_DIR}/")
  endif (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${dirname}.deps")
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/${dirname}.deps" DEP_LINES)
  string(TOLOWER "${proot}" lr)

  # Add each dependency to this directory's _DEPENDS list
  foreach(dl ${DEP_LINES})
    set(${proot}_DEPENDS ${${proot}_DEPENDS} ${dl})
  endforeach(dl ${DEP_LINES})

  # Add all dependencies to the global ALL_DEPENDENCIES list
  get_property(ALL_DEPS GLOBAL PROPERTY ALL_DEPENDENCIES)
  set(ALL_DEPS ${ALL_DEPS} ${${proot}_DEPENDS})
  list(SORT ALL_DEPS)
  list(REMOVE_DUPLICATES ALL_DEPS)
  set_property(GLOBAL PROPERTY ALL_DEPENDENCIES ${ALL_DEPS})

  # Set the TARGET variables for CMake generator expression "if" tests
  TargetVars(${proot}_DEPENDS)

endmacro(RegisterDeps)

macro(TargetInstallDeps croot roots)
  foreach(root ${${roots}})
    if (TARGET ${root}_BLD)
      ExternalProject_Add_stepdependencies(${croot}_BLD configure ${root}_BLD-install)
    endif (TARGET ${root}_BLD)
  endforeach(root ${${root}})
endmacro(TargetInstallDeps root)

###############################################################################
# We're using submodules to avoid automatically having to download a huge
# amount of source code if it isn't needed.  Define a convenience function
# to use in the project to populate the submodule checkouts if needed.
###############################################################################
function(bext_patch_command output_var)
  set(patch_command)
  foreach(patch_file IN LISTS ARGN)
    get_filename_component(patch_file "${patch_file}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    if (patch_command)
      list(APPEND patch_command COMMAND)
    endif ()
    list(APPEND patch_command
      "${PATCH_EXECUTABLE}" -E -p1 ${PATCH_OPTIONS} -i "${patch_file}")
  endforeach()
  set(${output_var} "${patch_command}" PARENT_SCOPE)
endfunction()

function(git_submodule_init path checkfile)
  cmake_parse_arguments(GSI "" "PATCH_COMMAND_VAR" "PATCH_FILES;INPUT_FILES" ${ARGN})
  if (GSI_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unknown git_submodule_init arguments: ${GSI_UNPARSED_ARGUMENTS}")
  endif ()
  if (GSI_PATCH_COMMAND_VAR AND NOT GSI_PATCH_FILES)
    message(FATAL_ERROR "git_submodule_init PATCH_COMMAND_VAR requires PATCH_FILES")
  endif ()

  string(REGEX REPLACE "[^A-Za-z0-9_+.-]" "_" stamp_name "${path}")
  set(sha1_stamp "${CMAKE_CURRENT_BINARY_DIR}/build_sha1_${stamp_name}.txt")
  if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${path}/${checkfile}")
    bext_git_submodule_update("${CMAKE_CURRENT_SOURCE_DIR}" -- "${path}")
    if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${path}/${checkfile}")
      message(FATAL_ERROR "Git submodule ${path} is missing ${checkfile} after checkout")
    endif ()
  endif ()

  execute_process(
    COMMAND git log -1 --format=%H
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${path}
    OUTPUT_VARIABLE SOURCE_STATE
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  set(normalized_patch_files)
  foreach(input_kind IN ITEMS PATCH_FILES INPUT_FILES)
    foreach(input_file IN LISTS GSI_${input_kind})
      get_filename_component(input_file "${input_file}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
      if (NOT EXISTS "${input_file}")
        message(FATAL_ERROR "Source input file does not exist: ${input_file}")
      endif ()
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${input_file}")
      file(SHA256 "${input_file}" input_sha256)
      string(APPEND SOURCE_STATE "\n${input_file}:${input_sha256}")
      if (input_kind STREQUAL "PATCH_FILES")
        list(APPEND normalized_patch_files "${input_file}")
      endif ()
    endforeach()
  endforeach()

  if (EXISTS "${sha1_stamp}")
    file(READ "${sha1_stamp}" BUILD_SOURCE_STATE)
    if (NOT "${BUILD_SOURCE_STATE}" STREQUAL "${SOURCE_STATE}")
      message("Outdated source stamp found for ${path}: resetting build directory ${CMAKE_CURRENT_BINARY_DIR}")
      execute_process(
        COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_CURRENT_BINARY_DIR}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/..
      )
      file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")
    endif ()
  endif ()
  file(WRITE "${sha1_stamp}" "${SOURCE_STATE}")
  set_property(DIRECTORY APPEND PROPERTY BEXT_SOURCE_STATE_FILES "${sha1_stamp}")

  if (GSI_PATCH_COMMAND_VAR)
    bext_patch_command(patch_command ${normalized_patch_files})
    set(${GSI_PATCH_COMMAND_VAR} "${patch_command}" PARENT_SCOPE)
  endif ()
endfunction(git_submodule_init path)

###############################################################################
# If we're using BRLCAD_COMPONENTS, the check of enabled/disabled is more
# nuanced.  For bext, the BRLCAD_COMPONENTS list should be the expanded list
# from BRL-CAD's parent logic that fully populates the dependencies, not just
# the components directly specified by the user to BRL-CAD's configure.
###############################################################################
function(cad_enable pname components)
  # Explicit local-build exclusions take precedence over component selection
  # and ENABLE_ALL. Keep the preference in the cache across reconfigures.
  if (DISABLE_${pname})
    set(ENABLE_${pname} OFF PARENT_SCOPE)
    set(DISABLE_${pname} ON PARENT_SCOPE)
    return()
  endif ()
  if (DEFINED BRLCAD_COMPONENTS)

    # To avoid problems passing multiple components in, we support using ':' as
    # a delimiter in addition to the standard CMake list entry delimiter ';'.
    # TODO: If this doesn't cut it we'll probably have to pass in a file
    # containing a list and read that.
    string(REPLACE ":" ";" BRLCAD_COMPONENTS "${BRLCAD_COMPONENTS}")

    set(acomponents ${components})

    # Look for a component in the list
    foreach(c ${BRLCAD_COMPONENTS})
      list(FIND acomponents ${c} LFIND)
      if (NOT LFIND EQUAL -1)
	bext_enable_all_default(${pname} ${pname})
	set(ENABLE_${pname} ${ENABLE_${pname}} PARENT_SCOPE)
	set(DISABLE_${pname} OFF PARENT_SCOPE)
	return()
      endif (NOT LFIND EQUAL -1)
    endforeach(c ${components})

    # If we're a component build and this component
    # isn't enabled, it's a definite off
    if (NOT DEFINED ENABLE_${pname})
      # Custom wrappers may cache their effective OFF decision. Remove only
      # these generated defaults after the wrapper finishes, never user OFFs.
      set_property(DIRECTORY APPEND PROPERTY BEXT_COMPONENT_DEFAULTS "ENABLE_${pname}")
    endif ()
    if (NOT DEFINED DISABLE_${pname})
      set_property(DIRECTORY APPEND PROPERTY BEXT_COMPONENT_DEFAULTS "DISABLE_${pname}")
    endif ()
    set(ENABLE_${pname} OFF)
    set(DISABLE_${pname} ON)
  endif (DEFINED BRLCAD_COMPONENTS)

  # Check for ENABLE_ALL
  bext_enable_all_default(${pname} ${pname})

  # Final decision
  set(ENABLE_${pname} ${ENABLE_${pname}} PARENT_SCOPE)
  set(DISABLE_${pname} ${DISABLE_${pname}} PARENT_SCOPE)
endfunction(cad_enable pname components)

###############################################################################
# The enable-disable-find logic for many dependencies follows a pattern.  Try
# to wrap that pattern up so we can more easily adjust it for multiple projects
# simultaneously.
###############################################################################
# Local snapshots are optional until their upstreams become submodules.  The
# source URL and revision also supply provenance to the dependency inventory.
function(bext_local_source pname path url revision)
  # Cache the user's preference, not source availability.  An absent snapshot
  # must be reconsidered on the next configure without losing an explicit OFF.
  set(ENABLE_${pname} ON CACHE BOOL "Build the local ${pname} snapshot when present")
  set(enabled OFF)
  if (ENABLE_${pname} AND NOT DISABLE_${pname})
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${path}/CMakeLists.txt")
      set(enabled ON)
    else ()
      message(STATUS "${pname}: local source ${path} is absent; build disabled")
    endif ()
  endif ()
  set(ENABLE_${pname} ${enabled} PARENT_SCOPE)
endfunction()

macro(bext_enable pname)
  string(TOUPPER "${pname}" upname)
  #string(TOLOWER "${pname}" lpname)

  if (DISABLE_${upname})
    # Component exclusions are effective decisions, not cached user choices.
    set(ENABLE_${upname} OFF)
  else ()
    bext_enable_all_default(${upname} ${pname})

    if (NOT ENABLE_${upname})

      # This is an optional probe: a "not found" result is the normal, expected
      # path that simply turns on the local build below, and the configure
      # summary already reports which packages are built locally vs. found on
      # the system. QUIET avoids verbose warnings for missing system packages.
      find_package(${pname} QUIET)

      if (NOT ${pname}_FOUND AND NOT DEFINED ENABLE_${upname})
        set(ENABLE_${upname} "ON" CACHE BOOL "Enable ${pname} build")
      endif (NOT ${pname}_FOUND AND NOT DEFINED ENABLE_${upname})

    endif ()
    set(ENABLE_${upname} "${ENABLE_${upname}}" CACHE BOOL "Enable ${pname} build")
  endif ()
endmacro(bext_enable pname)

###############################################################################
# Configure summary helpers
###############################################################################
macro(bext_enable_all_default enable_name summary_name)
  if (ENABLE_ALL AND NOT DEFINED ENABLE_${enable_name})
    set(ENABLE_${enable_name} ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_${enable_name})
  if (ENABLE_ALL AND ENABLE_${enable_name})
    string(TOUPPER "${summary_name}" bext_enable_all_tracking_name)
    string(REPLACE "-" "_" bext_enable_all_tracking_name "${bext_enable_all_tracking_name}")
    set(BEXT_ENABLE_ALL_FORCED_${bext_enable_all_tracking_name} ON CACHE INTERNAL "Project selected for local build while ENABLE_ALL is active")
  endif (ENABLE_ALL AND ENABLE_${enable_name})
endmacro(bext_enable_all_default enable_name summary_name)

function(_bext_summary_append property_name value)
  get_property(values GLOBAL PROPERTY ${property_name})
  list(APPEND values "${value}")
  list(REMOVE_DUPLICATES values)
  set_property(GLOBAL PROPERTY ${property_name} "${values}")
endfunction(_bext_summary_append property_name value)

function(_bext_summary_project_uses_local_build out pname upname)
  set(local_build FALSE)

  if (TARGET ${upname}_BLD)
    set(local_build TRUE)
  endif (TARGET ${upname}_BLD)

  # Read the wrapper's effective decision, which may differ from the cached
  # preference when an optional local snapshot is absent or disabled.
  get_directory_property(project_enabled DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${pname}"
    DEFINITION ENABLE_${upname})
  if (project_enabled)
    set(local_build TRUE)
  endif ()

  # A wrapper can own several build targets whose names differ from its own.
  get_property(project_targets DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${pname}"
    PROPERTY BUILDSYSTEM_TARGETS)
  foreach(project_target IN LISTS project_targets)
    if(project_target MATCHES "_BLD$")
      set(local_build TRUE)
      break()
    endif()
  endforeach()

  set(${out} ${local_build} PARENT_SCOPE)
endfunction(_bext_summary_project_uses_local_build out pname upname)

function(_bext_summary_list_to_string out values)
  set(list_values ${values})
  if (list_values)
    list(SORT list_values)
    string(REPLACE ";" ", " rendered "${list_values}")
  else (list_values)
    set(rendered "none")
  endif (list_values)
  set(${out} "${rendered}" PARENT_SCOPE)
endfunction(_bext_summary_list_to_string out values)

function(bext_print_configure_summary)
  set(active_groups)
  foreach(grp APPLESEED BRLCAD GDAL OSPRAY QT TCL)
    if (USE_${grp})
      list(APPEND active_groups ${grp})
    endif (USE_${grp})
  endforeach(grp APPLESEED BRLCAD GDAL OSPRAY QT TCL)

  get_property(local_projects GLOBAL PROPERTY BEXT_SUMMARY_LOCAL_PROJECTS)
  get_property(system_projects GLOBAL PROPERTY BEXT_SUMMARY_SYSTEM_PROJECTS)
  get_property(skipped_projects GLOBAL PROPERTY BEXT_SUMMARY_SKIPPED_PROJECTS)
  get_property(forced_projects GLOBAL PROPERTY BEXT_SUMMARY_ENABLE_ALL_PROJECTS)

  _bext_summary_list_to_string(active_groups_str "${active_groups}")
  _bext_summary_list_to_string(local_projects_str "${local_projects}")
  _bext_summary_list_to_string(system_projects_str "${system_projects}")
  _bext_summary_list_to_string(skipped_projects_str "${skipped_projects}")
  _bext_summary_list_to_string(forced_projects_str "${forced_projects}")

  message(STATUS "")
  message(STATUS "bext configure summary")
  message(STATUS "  active USE_* groups: ${active_groups_str}")
  message(STATUS "  local builds: ${local_projects_str}")
  message(STATUS "  not built locally: ${system_projects_str}")
  if (ENABLE_ALL)
    message(STATUS "  ENABLE_ALL local-build set: ${forced_projects_str}")
  endif (ENABLE_ALL)
  message(STATUS "  skipped because group inactive: ${skipped_projects_str}")
  message(STATUS "  bundled output root: ${CMAKE_BUNDLE_INSTALL_PREFIX}")
  message(STATUS "  noinstall output root: ${CMAKE_NOBUNDLE_INSTALL_PREFIX}")
  message(STATUS "")
endfunction(bext_print_configure_summary)

function(bext_install_exclude)
  foreach(pattern ${ARGN})
    if("${pattern}" STREQUAL "")
      message(FATAL_ERROR "bext_install_exclude requires non-empty patterns")
    endif()
    set_property(GLOBAL APPEND PROPERTY BEXT_INSTALL_EXCLUDE_PATTERNS "${pattern}")
  endforeach()
endfunction(bext_install_exclude)

function(bext_component_ownership component)
  foreach(pattern ${ARGN})
    if("${component}" STREQUAL "" OR "${pattern}" STREQUAL "")
      message(FATAL_ERROR "bext_component_ownership requires a component and non-empty patterns")
    endif()
    set_property(GLOBAL APPEND PROPERTY BEXT_COMPONENT_OWNERSHIP_RULES "${component}|${pattern}")
  endforeach()
endfunction(bext_component_ownership component)

function(bext_sbom_selector component)
  if(NOT component MATCHES "^[A-Za-z0-9][A-Za-z0-9+_.-]*$")
    message(FATAL_ERROR "Installed SBOM selector has an invalid component name: ${component}")
  endif()
  cmake_parse_arguments(SELECTOR "" "TARGET;SCRIPT;FUNCTION;CACHE" "ARGUMENTS" ${ARGN})
  if(SELECTOR_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unknown installed SBOM selector arguments for ${component}: ${SELECTOR_UNPARSED_ARGUMENTS}")
  endif()
  foreach(required TARGET SCRIPT FUNCTION CACHE)
    if(NOT SELECTOR_${required})
      message(FATAL_ERROR "Installed SBOM selector for ${component} requires ${required}")
    endif()
  endforeach()
  get_filename_component(selector_script "${SELECTOR_SCRIPT}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  get_filename_component(selector_cache "${SELECTOR_CACHE}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
  if(NOT EXISTS "${selector_script}")
    message(FATAL_ERROR "Installed SBOM selector for ${component} does not exist: ${selector_script}")
  endif()
  get_property(selector_components GLOBAL PROPERTY BEXT_SBOM_SELECTOR_COMPONENTS)
  if(component IN_LIST selector_components)
    message(FATAL_ERROR "Installed SBOM selector for ${component} is already registered")
  endif()
  string(SHA256 selector_id "${component}")
  set(preserved_cache "${CMAKE_BINARY_DIR}/CMakeFiles/bext-sbom-selector-caches/${selector_id}.cache")
  set_property(GLOBAL APPEND PROPERTY BEXT_SBOM_SELECTOR_COMPONENTS "${component}")
  set_property(GLOBAL APPEND PROPERTY BEXT_SBOM_SELECTOR_IDS "${selector_id}")
  set_property(GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_TARGET" "${SELECTOR_TARGET}")
  set_property(GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_COMPONENT" "${component}")
  set_property(GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_SCRIPT" "${selector_script}")
  set_property(GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_FUNCTION" "${SELECTOR_FUNCTION}")
  set_property(GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_CACHE" "${selector_cache}")
  set_property(GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_PRESERVED_CACHE" "${preserved_cache}")
  set_property(GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_ARGUMENTS" "${SELECTOR_ARGUMENTS}")
endfunction()

function(_bext_cmake_bracket_quote output value)
  set(equals "")
  while(TRUE)
    string(FIND "${value}" "]${equals}]" closing_bracket)
    if(closing_bracket EQUAL -1)
      break()
    endif()
    string(APPEND equals "=")
  endwhile()
  set(${output} "[${equals}[${value}]${equals}]" PARENT_SCOPE)
endfunction()

function(bext_write_sbom_selectors output)
  get_property(selector_ids GLOBAL PROPERTY BEXT_SBOM_SELECTOR_IDS)
  list(SORT selector_ids)
  _bext_cmake_bracket_quote(quoted_ids "${selector_ids}")
  file(WRITE "${output}" "set(BEXT_SBOM_SELECTOR_IDS ${quoted_ids})\n")
  foreach(selector_id IN LISTS selector_ids)
    foreach(field TARGET COMPONENT SCRIPT FUNCTION CACHE PRESERVED_CACHE ARGUMENTS)
      get_property(value GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_${field}")
      _bext_cmake_bracket_quote(quoted_value "${value}")
      file(APPEND "${output}" "set(BEXT_SBOM_SELECTOR_${selector_id}_${field} ${quoted_value})\n")
    endforeach()
  endforeach()
endfunction()

function(bext_component_manpage_ownership component)
  cmake_parse_arguments(M "" "INSTALL_SCRIPT" "" ${ARGN})
  file(GLOB manpages CONFIGURE_DEPENDS LIST_DIRECTORIES false ${M_UNPARSED_ARGUMENTS})
  if (M_INSTALL_SCRIPT)
    # Core Tcl/Tk installs aliases from each page's NAME section. Use its own
    # installer to obtain the complete filename set without duplicating that
    # parsing or claiming manuals belonging to another component.
    find_program(BEXT_MANPAGE_SHELL sh REQUIRED)
    mark_as_advanced(BEXT_MANPAGE_SHELL)
    set(ownership_root "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${component}-manpages")
    file(REMOVE_RECURSE "${ownership_root}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${M_INSTALL_SCRIPT}")
  endif ()
  foreach(manpage IN LISTS manpages)
    get_filename_component(section "${manpage}" LAST_EXT)
    string(SUBSTRING "${section}" 1 -1 section)
    if (NOT section MATCHES "^(1|3|n)$")
      message(FATAL_ERROR "Unsupported manual section: ${manpage}")
    endif ()
    if (M_INSTALL_SCRIPT)
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${manpage}")
      set(section_root "${ownership_root}/man${section}")
      file(MAKE_DIRECTORY "${section_root}")
      execute_process(
        COMMAND "${BEXT_MANPAGE_SHELL}" "${M_INSTALL_SCRIPT}" "${manpage}" "${section_root}"
        RESULT_VARIABLE install_result
        OUTPUT_VARIABLE install_output
        ERROR_VARIABLE install_error)
      if (NOT install_result EQUAL 0)
        message(FATAL_ERROR
          "Unable to enumerate manual ownership for ${manpage}: "
          "${install_output}${install_error}")
      endif ()
    else ()
      get_filename_component(manpage_name "${manpage}" NAME)
      string(REPLACE "." "[.]" manpage_name "${manpage_name}")
      bext_component_ownership("${component}" "^(share/)?man/man${section}/${manpage_name}$")
    endif ()
  endforeach()
  if (M_INSTALL_SCRIPT)
    file(GLOB_RECURSE installed_pages LIST_DIRECTORIES false
      RELATIVE "${ownership_root}" "${ownership_root}/*")
    foreach(manpage IN LISTS installed_pages)
      string(REPLACE "." "[.]" manpage "${manpage}")
      bext_component_ownership("${component}" "^(share/)?man/${manpage}$")
    endforeach()
    file(REMOVE_RECURSE "${ownership_root}")
  endif ()
endfunction()

function(_bext_register_package_legal_ownership pname)
  bext_inventory_get(package_legal_names "${pname}" LEGAL_NAMES)
  foreach(legal_name ${package_legal_names})
    bext_component_ownership("${pname}" "^share/doc/legal/other/${legal_name}(/|[.]txt$)")
  endforeach()
endfunction()

###############################################################################
# The primary add_project function used to add individual dependency
# directories.
###############################################################################
function(_bext_clear_component_defaults pname)
  get_property(defaults DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${pname}"
    PROPERTY BEXT_COMPONENT_DEFAULTS)
  foreach(name IN LISTS defaults)
    unset(${name} CACHE)
  endforeach ()
endfunction()

function(add_project pname)
  cmake_parse_arguments(A "" "" "GROUPS" ${ARGN})
  bext_load_package_descriptor("${CMAKE_SOURCE_DIR}" "${pname}")
  bext_inventory_get(package_groups "${pname}" GROUPS)
  set(requested_groups ${A_GROUPS})
  list(SORT package_groups)
  list(SORT requested_groups)
  if(NOT "${package_groups}" STREQUAL "${requested_groups}")
    message(FATAL_ERROR
      "add_project(${pname}) groups do not match ${pname}/BextPackage.cmake: "
      "requested '${requested_groups}', registered '${package_groups}'")
  endif()
  string(TOUPPER "${pname}" UPNAME)
  string(REPLACE "-" "_" UPNAME "${UPNAME}")
  set(is_added FALSE)
  if (NOT A_GROUPS)
    set(is_added TRUE)
  else ()
    foreach(grp ${A_GROUPS})
      if (USE_${grp})
        set(is_added TRUE)
        break()
      endif ()
    endforeach()
  endif ()
  if (is_added)
    if (A_GROUPS AND BEXT_DISCARD_WORK)
      add_subdirectory(${pname} EXCLUDE_FROM_ALL)
    else ()
      add_subdirectory(${pname})
    endif ()
    _bext_clear_component_defaults(${pname})
    # A wrapper may resolve several providers, including system tools. Mark
    # all declared providers handled before later wrappers inspect ordering.
    bext_inventory_get(providers "${pname}" PROVIDERS)
    foreach(provider ${pname} ${providers})
      string(TOUPPER "${provider}" provider_name)
      string(REPLACE "-" "_" provider_name "${provider_name}")
      set(${provider_name}_ADDED 1 PARENT_SCOPE)
    endforeach()
    _bext_summary_project_uses_local_build(local_build ${pname} ${UPNAME})
    if (local_build)
      _bext_register_package_legal_ownership("${pname}")
      _bext_summary_append(BEXT_SUMMARY_LOCAL_PROJECTS ${pname})
      if (ENABLE_ALL AND BEXT_ENABLE_ALL_FORCED_${UPNAME})
        _bext_summary_append(BEXT_SUMMARY_ENABLE_ALL_PROJECTS ${pname})
      endif (ENABLE_ALL AND BEXT_ENABLE_ALL_FORCED_${UPNAME})
    else (local_build)
      _bext_summary_append(BEXT_SUMMARY_SYSTEM_PROJECTS ${pname})
    endif (local_build)
  endif (is_added)
  if (NOT is_added)
    _bext_summary_append(BEXT_SUMMARY_SKIPPED_PROJECTS ${pname})
    if (ENABLE_${UPNAME})
      message("Disabling ${pname}")
      set(STALE_INSTALL_WARN TRUE PARENT_SCOPE)
    endif (ENABLE_${UPNAME})
    execute_process(COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_BINARY_DIR}/${pname})
    # Preserve explicit OFF preferences when a group is disabled and enabled
    # again. Other cached build decisions can be reconsidered when it returns.
    if (ENABLE_${UPNAME})
      unset(ENABLE_${UPNAME} CACHE)
    endif ()
  endif (NOT is_added)
endfunction(add_project pname)

###############################################################################
# Make the built-in clean target reset ExternalProject working state without
# requiring a top-level CMake reconfigure.  We preserve the generated control
# files in STAMP_DIR and TMP_DIR, but remove the step marker files and any
# generated source/build directories that can be safely recreated by the next
# build.
###############################################################################
function(_bext_collect_subdirs out dir)
  set(dirs "${dir}")
  get_property(subdirs DIRECTORY "${dir}" PROPERTY SUBDIRECTORIES)
  foreach(subdir ${subdirs})
    _bext_collect_subdirs(child_dirs "${subdir}")
    list(APPEND dirs ${child_dirs})
  endforeach()
  set(${out} "${dirs}" PARENT_SCOPE)
endfunction(_bext_collect_subdirs out dir)

function(_bext_path_is_in_build_tree out path)
  if (NOT path)
    set(${out} FALSE PARENT_SCOPE)
    return()
  endif()

  file(RELATIVE_PATH rel "${CMAKE_BINARY_DIR}" "${path}")
  if (IS_ABSOLUTE "${rel}" OR "${rel}" MATCHES "^\\.\\.")
    set(${out} FALSE PARENT_SCOPE)
  else()
    set(${out} TRUE PARENT_SCOPE)
  endif()
endfunction(_bext_path_is_in_build_tree out path)

function(_bext_register_extproject_clean ep_target)
  if (NOT TARGET ${ep_target})
    return()
  endif()

  ExternalProject_Get_Property(${ep_target} SOURCE_DIR)
  set(ep_source_dir "${SOURCE_DIR}")
  ExternalProject_Get_Property(${ep_target} BINARY_DIR)
  set(ep_build_dir "${BINARY_DIR}")
  ExternalProject_Get_Property(${ep_target} STAMP_DIR)
  set(ep_stamp_dir "${STAMP_DIR}")

  _bext_path_is_in_build_tree(ep_source_is_generated "${ep_source_dir}")
  _bext_path_is_in_build_tree(ep_build_is_generated "${ep_build_dir}")

  set(clean_files
    "${ep_stamp_dir}/${ep_target}-mkdir"
    "${ep_stamp_dir}/${ep_target}-configure"
    "${ep_stamp_dir}/${ep_target}-build"
    "${ep_stamp_dir}/${ep_target}-install"
    "${ep_stamp_dir}/${ep_target}-done"
    )

  # If the source tree is a generated copy in the build directory, remove it
  # and force the full download/update/patch pipeline to rerun on next build.
  if (ep_source_is_generated)
    list(APPEND clean_files
      "${ep_stamp_dir}/${ep_target}-download"
      "${ep_stamp_dir}/${ep_target}-update"
      "${ep_stamp_dir}/${ep_target}-patch"
      "${ep_source_dir}"
      )
  endif()

  # Some wrappers use a separate generated binary directory outside the default
  # *_BLD-prefix/src tree (Qt is the main case.)  If it lives in the build tree
  # and isn't the same path as SOURCE_DIR, it is safe to remove here.
  if (ep_build_is_generated AND NOT "${ep_build_dir}" STREQUAL "${ep_source_dir}")
    list(APPEND clean_files "${ep_build_dir}")
  endif()

  list(REMOVE_DUPLICATES clean_files)
  set_property(TARGET ${ep_target} APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${clean_files}")
  if (TARGET ${ep_target}-install)
    set_property(TARGET ${ep_target}-install APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${clean_files}")
  endif()
endfunction(_bext_register_extproject_clean ep_target)

function(register_external_project_clean_targets)
  _bext_collect_subdirs(all_dirs "${CMAKE_SOURCE_DIR}")
  list(REMOVE_DUPLICATES all_dirs)
  foreach(dir ${all_dirs})
    get_property(dir_targets DIRECTORY "${dir}" PROPERTY BUILDSYSTEM_TARGETS)
    foreach(dir_target ${dir_targets})
      if ("${dir_target}" MATCHES "_BLD$")
        _bext_register_extproject_clean("${dir_target}")
      endif()
    endforeach()
  endforeach()
endfunction(register_external_project_clean_targets)


# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
