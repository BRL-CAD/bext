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
#
# FIXME: Dependencies are also added here to a .dot file dependency
# graph file, but that shouldn't be intertwined here as side effect.
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

  # Add each dependency to a global .dot file
  foreach(dl ${DEP_LINES})
    string(TOLOWER "${dl}" ldl)
    if (NOT "${ldl}" STREQUAL "patch")
      file(APPEND "${CMAKE_BINARY_DIR}/bext.dot" "\t${lr} -> ${ldl};\n")
    endif (NOT "${ldl}" STREQUAL "patch")
  endforeach(dl ${DEP_LINES})

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
function(git_submodule_init path checkfile)
  if (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${path}/${checkfile})
    find_program(GIT_EXECUTABLE git)
    if (NOT GIT_EXECUTABLE)
      message(FATAL_ERROR "Need to populate Git submodule, but unable to find git executable")
    endif (NOT GIT_EXECUTABLE)
    if (NOT GIT_SHALLOW_CLONE)
      execute_process(
	COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive ${path}
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      )
    else (NOT GIT_SHALLOW_CLONE)
      execute_process(
	COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive --recommend-shallow ${path}
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      )
    endif (NOT GIT_SHALLOW_CLONE)
  endif (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${path}/${checkfile})
endfunction(git_submodule_init path)

###############################################################################
# If we're using BRLCAD_COMPONENTS, the check of enabled/disabled is more
# nuanced.  For bext, the BRLCAD_COMPONENTS list should be the expanded list
# from BRL-CAD's parent logic that fully populates the dependencies, not just
# the components directly specified by the user to BRL-CAD's configure.
###############################################################################
function(cad_enable pname components)
  if (DEFINED BRLCAD_COMPONENTS)

    # To avoid problems passing multiple components in, we support using ':' as
    # a delimiter in addition to the standard CMake list entry delimiter ';'.
    # TODO: If this doesn't cut it we'll probably have to pass in a file
    # containing a list and read that.
    string(REPLACE ":" ";" BRLCAD_COMPONENTS "${BRLCAD_COMPONENTS}")

    # In case the component list changed, make sure we're
    # not using a cached result.
    unset(ENABLE_${pname} CACHE)
    unset(DISABLE_${pname} CACHE)

    set(acomponents ${components})

    # Look for a component in the list
    foreach(c ${BRLCAD_COMPONENTS})
      list(FIND acomponents ${c} LFIND)
      if (NOT LFIND EQUAL -1)
	if (ENABLE_ALL AND NOT DEFINED ENABLE_${pname})
	  set(ENABLE_${pname} ON PARENT_SCOPE)
	endif (ENABLE_ALL AND NOT DEFINED ENABLE_${pname})
	set(DISABLE_${pname} OFF PARENT_SCOPE)
	return()
      endif (NOT LFIND EQUAL -1)
    endforeach(c ${components})

    # If we're a component build and this component
    # isn't enabled, it's a definite off
    set(ENABLE_${pname} OFF)
    set(DISABLE_${pname} ON)
  endif (DEFINED BRLCAD_COMPONENTS)

  # Check for ENABLE_ALL
  if (ENABLE_ALL AND NOT DEFINED ENABLE_${pname})
    set(ENABLE_${pname} ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_${pname})

  # Final decision
  set(ENABLE_${pname} ${ENABLE_${pname}} PARENT_SCOPE)
  set(DISABLE_${pname} ${DISABLE_${pname}} PARENT_SCOPE)
endfunction(cad_enable pname components)

###############################################################################
# The enable-disable-find logic for many dependencies follows a pattern.  Try
# to wrap that pattern up so we can more easily adjust it for multiple projects
# simultaneously.
###############################################################################
macro(bext_enable pname)
  string(TOUPPER "${pname}" upname)
  #string(TOLOWER "${pname}" lpname)

  if (ENABLE_ALL AND NOT DEFINED ENABLE_${upname})
    set(ENABLE_${upname} ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_${upname})

  if (NOT ENABLE_${upname} AND NOT DISABLE_${upname})

    find_package(${pname})

    if (NOT ${pname}_FOUND AND NOT DEFINED ENABLE_${upname})
      set(ENABLE_${upname} "ON" CACHE BOOL "Enable ${pname} build")
    endif (NOT ${pname}_FOUND AND NOT DEFINED ENABLE_${upname})

  endif (NOT ENABLE_${upname} AND NOT DISABLE_${upname})
  set(ENABLE_${upname} "${ENABLE_${upname}}" CACHE BOOL "Enable ${pname} build")
endmacro(bext_enable pname)

###############################################################################
# The primary add_project function used to add individual dependency
# directories.
###############################################################################
function(add_project pname)
  cmake_parse_arguments(A "" "" "GROUPS" ${ARGN})
  string(TOUPPER "${pname}" UPNAME)
  string(REPLACE "-" "_" UPNAME "${UPNAME}")
  if (NOT A_GROUPS)
    add_subdirectory(${pname})
    set(${UPNAME}_ADDED 1 PARENT_SCOPE)
    return()
  endif (NOT A_GROUPS)
  set(is_added FALSE)
  foreach(grp ${A_GROUPS})
    if (USE_${grp})
      add_subdirectory(${pname})
      set(is_added TRUE)
      set(${UPNAME}_ADDED 1 PARENT_SCOPE)
      break()
    endif (USE_${grp})
  endforeach(grp ${A_GROUPS})
  if (NOT is_added)
    if (ENABLE_${UPNAME})
      message("Disabling ${pname}")
      set(STALE_INSTALL_WARN TRUE PARENT_SCOPE)
    endif (ENABLE_${UPNAME})
    execute_process(COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_BINARY_DIR}/${pname})
    unset(ENABLE_${UPNAME} CACHE)
  endif (NOT is_added)
endfunction(add_project pname)


# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

