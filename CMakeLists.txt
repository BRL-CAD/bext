#------------------------------------------------------------------------------
# Management of External Libraries
#
# Large scale computer graphics tools such as BRL-CAD depend on a variety of
# external libraries and tools - rather than fail if those requirements are not
# satisfied by a system's available packages, we build local copies at need.
#
# There are three overall approaches to the handling of these
# dependencies:
#
# 1.  Auto - detect system libraries and use them if suitable, otherwise build
#     and use the local copy.  This is the default approach.
#
# 2.  Bundled - regardless of system conditions, build and use all bundled
#     libraries.
#
# 3.  System - fail to build if the system libraries do not satisfy
#     requirements.  This is primarily useful for distributions that want to
#     ensure packages are using external libraries.
#
# In addition to the broad toplevel control, individual libraries can also be
# overridden - for example, if the toplevel setting is for Bundled libs, it is
# still possible to request a system library in individual cases.
#------------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.19)

project(BEXT)

# With this policy the ExternalProject_Add() STEP_TARGETS option, and the
# ExternalProject_Add_StepTargets() function, can be used to create build
# targets for individual steps of an external project.  We make use of
# this feature, so we require at least CMake 3.19
if (POLICY CMP0114)
  cmake_policy(SET CMP0114 NEW)
endif (POLICY CMP0114)

# Require at least C++17 - some of the targeted dependencies require this.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Location of CMake modules.  It is common for us to mod Find* package scripts
# to respect *_ROOT variable settings, necessary when having CMake builds
# target locally bundled copies of libraries rather than system installed
# versions.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake")

#------------------------------------------------------------------------------
# To match the BRL-CAD configurations, limit bext builds to a single type

# Normalize the build type capitalization
if(CMAKE_BUILD_TYPE)
  string(TOUPPER "${CMAKE_BUILD_TYPE}" BUILD_TYPE_UPPER)
  if ("${BUILD_TYPE_UPPER}" STREQUAL "RELEASE")
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build Type" FORCE)
  endif ("${BUILD_TYPE_UPPER}" STREQUAL "RELEASE")
  if ("${BUILD_TYPE_UPPER}" STREQUAL "DEBUG")
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Build Type" FORCE)
  endif ("${BUILD_TYPE_UPPER}" STREQUAL "DEBUG")
endif(CMAKE_BUILD_TYPE)

# CMake configuration types need to be overridden.  If a CMAKE_BUILD_TYPE
# has been specified, use that - otherwise default to Debug.
if(CMAKE_CONFIGURATION_TYPES)
  if (CMAKE_BUILD_TYPE)
    set(CMAKE_CONFIGURATION_TYPES "${CMAKE_BUILD_TYPE}" CACHE STRING "Force a single build type" FORCE)
  else (CMAKE_BUILD_TYPE)
    set(CMAKE_CONFIGURATION_TYPES "Debug" CACHE STRING "Force a single build type" FORCE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Build Type" FORCE)
  endif (CMAKE_BUILD_TYPE)
endif(CMAKE_CONFIGURATION_TYPES)

mark_as_advanced(CMAKE_BUILD_TYPE)
mark_as_advanced(CMAKE_CONFIGURATION_TYPES)

# Frameworks are deprecated in CMake, so avoid finding them
set(CMAKE_FIND_FRAMEWORK NEVER)


#------------------------------------------------------------------------------
# Once we do a run, we want our ENABLE_ALL setting to be consistent in
# subsequent CMake runs
if (ENABLE_ALL)
  set(ENABLE_ON "ON" CACHE BOOL "Enable all local versions of packages")
else (ENABLE_ALL)
  set(ENABLE_ON "OFF" CACHE BOOL "Prefer system versions of packages")
endif (ENABLE_ALL)

#------------------------------------------------------------------------------
# We do NOT want CMake looking in the User Package Registry - have encountered
# at least one case where stale or incorrect information there has resulted in
# an incorrect include directory for Eigen based on bext build info.
#
# TODO - may want/need to pass this as a -D argument to the ExternalProject_Add
# calls as well...
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)

# If we're not multiconfig and the user hasn't specified something, go with
# Release mode.  We're generally looking to bundle these as if they were system
# libraries, so that's going to mean we want release configurations.
if (NOT CMAKE_CONFIGURATION_TYPES AND NOT DEFINED CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif (NOT CMAKE_CONFIGURATION_TYPES AND NOT DEFINED CMAKE_BUILD_TYPE)

# Define some variables
if(NOT DEFINED BIN_DIR)
  set(BIN_DIR bin)
endif(NOT DEFINED BIN_DIR)
if(NOT DEFINED INCLUDE_DIR)
  set(INCLUDE_DIR include)
endif(NOT DEFINED INCLUDE_DIR)
if(NOT DEFINED LIB_DIR)
  set(LIB_DIR lib)
endif(NOT DEFINED LIB_DIR)
if(NOT DEFINED DATA_DIR)
  set(DATA_DIR share)
endif(NOT DEFINED DATA_DIR)

# install is the target for projects that will be incorporated into parent
# software binary distributions.  For tools like astyle and plief that are
# build tools only, we instead place them in noinstall.  We need a parent
# directory to hold both of these outputs, and we want it to be in a standard
# location that other projects will know to look for.

# Default to the build directory for output and installation
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set (CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}" CACHE PATH "default install path" FORCE)
endif (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)

# Make sure subsequent configures stick with the same installation path, whether specified or not
set(CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}" CACHE PATH "Calculated or specified install prefix" FORCE)

message("prefix is ${CMAKE_INSTALL_PREFIX}")

set(CMAKE_BUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/install" CACHE PATH "Outputs for bundling" FORCE)
set(CMAKE_NOBUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/noinstall" CACHE PATH "Build tools NOT intended for bundling" FORCE)
file(MAKE_DIRECTORY "${CMAKE_BUNDLE_INSTALL_PREFIX}")
file(MAKE_DIRECTORY "${CMAKE_NOBUNDLE_INSTALL_PREFIX}")

# We want to install the license files where BRL-CAD expects them
# to be
set(DOC_LICENSE_DIR ${CMAKE_BUNDLE_INSTALL_PREFIX}/share/doc/legal/other)
file(MAKE_DIRECTORY ${DOC_LICENSE_DIR})

#---------------------------------------------------------------------
# By default, changes in ExternalProject_Add directories won't trigger
# rebuilding of those targets.  Setting this to 1 changes that, but at the
# expense of running the build step every time.  This may be fast if there is
# nothing to update in the project, but it will be slower than skipping the
# step completely.
if (NOT DEFINED EXT_BUILD_ALWAYS)
  set(EXT_BUILD_ALWAYS 1)
endif (NOT DEFINED EXT_BUILD_ALWAYS)

# The verbosity of the ExtProject stages is controlled by log options - they
# can either output to the console or to log files.  We establish a top level
# control for this - by default these outputs are logged, but if the verbose
# flag is set they will be printed to the console during build (useful in
# scenarios such as CI build runners, where it is advantageous to capture as
# much output as possible in the top level log.
if (EXT_BUILD_VERBOSE)
  set(EXT_BUILD_QUIET OFF)
else (EXT_BUILD_VERBOSE)
  set(EXT_BUILD_QUIET ON)
endif (EXT_BUILD_VERBOSE)

# Use the superbuild pattern (see, for example,
# https://www.kitware.com/cmake-superbuilds-git-submodules) via CMake's
# ExternalProject_Add feature to manage 3rd party builds
include(ExternalProject)

# In case we need to pass some sort of reasonable parallel
# flag to a build system, check our processor count
include(ProcessorCount)
ProcessorCount(N)
math(EXPR pcnt "${N} / 2")
if (NOT pcnt)
  set(pcnt 1)
endif (NOT pcnt)

# We want to pass the build type option to CMake builds if we're not using a
# multiconfig generator - define a variable that will either be empty or define
# the desired CMake line based on GENERATOR_IS_MULTI_CONFIG (see
# https://gitlab.kitware.com/cmake/cmake/-/issues/20921)
get_property(isMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
set(BUILD_TYPE_SPECIFIER)
if (NOT isMultiConfig)
  set(BUILD_TYPE_SPECIFIER "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
endif (NOT isMultiConfig)

# With MSVC, some of the non-CMake subbuilds are going to need the vcvars bat
# file to set up the environment.
if(MSVC)

  get_filename_component(COMPILER_DIR "${CMAKE_C_COMPILER}" DIRECTORY)
  get_filename_component(COMPILER_ROOT "${COMPILER_DIR}" NAME)
  set(VCVARS_BAT "${COMPILER_DIR}/vcvars${COMPILER_ROOT}.bat")
  if(NOT EXISTS "${VCVARS_BAT}")
    # Try the VS2017 location (https://stackoverflow.com/q/43372235)
    set(COMPILER_ROOT "")
    foreach(DIRS RANGE 0 5)
      get_filename_component(COMPILER_DIR "${COMPILER_DIR}" DIRECTORY)
    endforeach(DIRS RANGE 0 5)
    set(COMPILER_DIR "${COMPILER_DIR}/Auxiliary/Build")
    if(CMAKE_CL_64)
      set(VCVARS_BAT "${COMPILER_DIR}/vcvars64.bat")
    else(CMAKE_CL_64)
      set(VCVARS_BAT "${COMPILER_DIR}/vcvars32.bat")
    endif(CMAKE_CL_64)
    if(NOT EXISTS "${VCVARS_BAT}")
      message(FATAL_ERROR "Could not find vcvars bat file in ${COMPILER_DIR}")
    endif(NOT EXISTS "${VCVARS_BAT}")
  endif(NOT EXISTS "${VCVARS_BAT}")

endif(MSVC)

# Add a target that will run every time we build and touch a file in
# noinstall to allow interested parent CMake builds to be aware of potential
# changes, even if all that happens is to add files - otherwise, add-only
# operations won't trigger a CMake reconfigure even if the client build is
# watching the install files.
file(MAKE_DIRECTORY ${CMAKE_NOBUNDLE_INSTALL_PREFIX})
add_custom_target(BuildStamp ALL COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_NOBUNDLE_INSTALL_PREFIX}/build-stamp)


###############################################################################
# It is common for more complex targets to need to key build settings off of
# whether or not their dependencies are being built locally.  These macros are
# used to cut down on boilerplate code
###############################################################################
configure_file("${CMAKE_SOURCE_DIR}/dependencies.dot" "${CMAKE_BINARY_DIR}/bext.dot" COPYONLY)

macro(TargetVars roots)
  foreach(root ${${roots}})
    if (NOT ${root}_ADDED)
      message(FATAL_ERROR "${root} is listed as a dependency but is not yet added - fix project ordering in top level CMakeLists.txt file")
    endif (NOT ${root}_ADDED)
    if (TARGET ${root}_BLD)
      set(${root}_TARGET 1)
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
# There are a large number of external packages that may need to be built -
# some of these are "dependencies of dependencies" which may be needed only if
# specific high level capabilities are sought.  In order to try to make clear
# *why* various packages are present (and make it easier to skip building them
# if a particular high level feature is not of interest) we create options used
# as "tags" that control adding packages.  If at least one of the tags for a
# given package is set, that package will be built.
###############################################################################
option(USE_APPLESEED    "Appleseed rendering system"                 OFF)
option(USE_BRLCAD       "BRL-CAD core dependencies"                  ON)
option(USE_BRLCAD_EXTRA "BRL-CAD dependencies that can be disabled"  ON)
option(USE_GDAL         "GDAL terrain support"                       ON)
option(USE_OSPRAY       "OSPRay rendering system"                    OFF)
option(USE_QT           "Qt graphical toolkit support"               ON)
option(USE_TCL          "Tcl/Tk support"                             ON)

# If we're using BRLCAD_COMPONENTS, the check is more nuanced.
# For bext, the BRLCAD_COMPONENTS list should be the expanded
# list from BRL-CAD's parent logic that fully populates the
# dependencies, not just the components directly specified by
# the user to BRL-CAD's configure.
function(cad_enable pname components)
  if (DEFINED BRLCAD_COMPONENTS)
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

# The enable-disable-find logic for a lot of these follows a
# pattern.  Try to wrap that pattern up so we can more easily
# adjust it for multiple projects simultaneously.
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


# If configurations change after a build has been performed,
# we don't automatically scrub a pre-existing output directory
# to remove the files from the newly disabled components.
# Warn the user of this
set(STALE_INSTALL_WARN FALSE)

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

###############################################################################
# Python is a build-time dependency for both LLVM and ISPC.  I think
# it's only build time in both cases, but short of a lot of rework the
# upstreams probably wouldn't be inclined to take anyway we're going
# to have to have it available.  Unfortunately, bootstrapping our own
# local copy is problematic on Linux right now - saw this issue immediately
# when I tried:  https://github.com/python/cpython/issues/90737
#
# What we might be able to do for this is try building Python3 IFF we don't
# find a system Python3 if we really don't need to bundle it - if we don't
# have a system version available there wont' be anything to conflict with.
# For now just hard require it and move on...
if (USE_APPLESEED OR USE_OSPRAY)
  find_package(Python3 REQUIRED)
endif (USE_APPLESEED OR USE_OSPRAY)
###############################################################################

###############################################################################
# For the moment, we can't bootstrap GNU m4 readily, and ISPC *needs* it for
# compilation.  (Ideally we would enhance the OpenBSD m4 to support the ISPC
# features needed, but as of 2023-09-18 it doesn't have them yet.)
###############################################################################
if (USE_OSPRAY)
  find_program(M4_EXECUTABLE m4 REQUIRED)
endif (USE_OSPRAY)

###############################################################################
# There are a lot of individual projects, and their ordering is important.  We
# store them as a separate file.
###############################################################################
include("${CMAKE_SOURCE_DIR}/dependencies.cmake")

# Now that we have the dependencies specified, finish the dependencies DOT file
file(APPEND "${CMAKE_BINARY_DIR}/bext.dot" "\n}\n")

###############################################################################
# Warn the user if the settings changed in a way the indicate there is a risk
# of now-disabled build products in the output directory
###############################################################################
if (EXISTS "${CMAKE_BUNDLE_INSTALL_PREFIX}" AND STALE_INSTALL_WARN)
  file(GLOB OFILES_BIN LIST_DIRECTORIES TRUE ${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/* )
  file(GLOB OFILES_LIB LIST_DIRECTORIES TRUE ${CMAKE_BUNDLE_INSTALL_PREFIX}/lib/* )
  if (OFILES_BIN OR OFILES_LIB)
    message(WARNING "\nBuild settings have changed, but build outputs are already present in ${CMAKE_BUNDLE_INSTALL_PREFIX}.  Recommend clearing the directory to avoid unexpected files being present when using the build outputs to support compilation.\n")
  endif (OFILES_BIN OR OFILES_LIB)
endif (EXISTS "${CMAKE_BUNDLE_INSTALL_PREFIX}" AND STALE_INSTALL_WARN)

###############################################################################
# On Windows, if we get dlls built for the wrong configuration it can cause
# problems.  Define a utility target to check
###############################################################################
add_custom_target(dll_typecheck
  COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=\"$<CONFIG>\" -DDLL_DIR=\"${CMAKE_INSTALL_PREFIX}/bext_output/install/bin\" -P ${CMAKE_SOURCE_DIR}/CMake/DllTypeCheck.cmake)

###############################################################################
# Check that Windows LoadLibrary call can succeed with our dll outputs
###############################################################################
if (WIN32)
  add_executable(lltest ${CMAKE_SOURCE_DIR}/CMake/LoadLibraryTest.cpp)
  add_custom_target(dll_loadcheck
    COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=\"$<CONFIG>\" -DLEXEC=\"$<TARGET_FILE:lltest>\" -DDLL_DIR=\"${CMAKE_INSTALL_PREFIX}/bext_output/install/bin\" -P ${CMAKE_SOURCE_DIR}/CMake/LoadLibraryCheck.cmake
    DEPENDS lltest
    )
endif (WIN32)

###############################################################################
# Report where we will be putting our output
###############################################################################
message("Output directory: ${CMAKE_INSTALL_PREFIX}")

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

