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

# extinstall is the target for projects that will be incorporated into parent
# software binary distributions.  For tools like astyle and plief that are
# build tools only, we instead place them in extnoinstall.  We need a parent
# directory to hold both of these outputs, and we want it to be in a standard
# location that other projects will know to look for.

# Try to get the home directory
set(ENV_HOME "$ENV{HOME}")
if (NOT ENV_HOME)
  set(ENV_HOME "$ENV{USERPROFILE}")
endif (NOT ENV_HOME)

# If we're not being forced to a specific location
# and we know where home is, use it
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${ENV_HOME}")
endif (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)

# If home didn't work, fall back on the build directory
if (NOT CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}")
endif (NOT CMAKE_INSTALL_PREFIX)

# Having decided on the path, make sure subsequent configures stick with it
set(CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}" CACHE PATH "Calculated or specified install prefix" FORCE)

set(BEXT_ROOT bext_install)
set(CMAKE_BUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/${BEXT_ROOT}/extinstall" CACHE PATH "Outputs for bundling" FORCE)
set(CMAKE_NOBUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/${BEXT_ROOT}/extnoinstall" CACHE PATH "Build tools NOT intended for bundling" FORCE)
file(MAKE_DIRECTORY "${CMAKE_BUNDLE_INSTALL_PREFIX}")
file(MAKE_DIRECTORY "${CMAKE_NOBUNDLE_INSTALL_PREFIX}")

#---------------------------------------------------------------------
# By default, changes in ExternalProject_Add directories won't trigger
# rebuilding of those targets.  Setting this to 1 changes that, but at the
# expense of running the build step every time.  This may be fast if there is
# nothing to update in the project, but it will be slower than skipping the
# step completely.
if (NOT DEFINED EXT_BUILD_ALWAYS)
  set(EXT_BUILD_ALWAYS 0)
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
# extnoinstall to allow interested parent CMake builds to be aware of potential
# changes, even if all that happens is to add files - otherwise, add-only
# operations won't trigger a CMake reconfigure even if the client build is
# watching the extinstall files.
file(MAKE_DIRECTORY ${CMAKE_NOBUNDLE_INSTALL_PREFIX})
add_custom_target(BuildStamp ALL COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_NOBUNDLE_INSTALL_PREFIX}/build-stamp)


###############################################################################
# There are a large number of external packages that may need to be built -
# some of these are "dependencies of dependencies" which may be needed only if
# specific high level capabilities are sought.  In order to try to make clear
# *why* various packages are present (and make it easier to skip building them
# if a particular high level feature is not of interest) we create options used
# as "tags" that control adding packages.  If at least one of the tags for a
# given package is set, that package will be built.
###############################################################################
option(USE_BRLCAD "BRL-CAD required dependency"  ON)
option(USE_GDAL   "GDAL terrain support"         ON)
option(USE_QT     "Qt graphical toolkit support" ON)
option(USE_TCL    "Tcl/Tk support"               ON)

function(add_project pname)
  cmake_parse_arguments(A "" "GROUPS" "" ${ARGN})
  if (NOT A_GROUPS)
    add_subdirectory(${pname})
    return()
  endif (NOT A_GROUPS)
  foreach(grp ${A_GROUPS})
    if (USE_${grp})
      add_subdirectory(${pname})
      return()
    endif (USE_${grp})
  endforeach(grp ${A_GROUPS})
endfunction(add_project pname)

# With git submodules it's common to forget to clone with --recurse-submodules
if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/patch/patch/README.md")
  message(FATAL_ERROR "Repository clone is not fully populated - run\ngit submodule update --init --recursive\n\nTo clone with modules initially, use:\ngit clone --recurse-submodules")
endif (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/patch/patch/README.md")

###############################################################################
# Applying patch files cross platform is a challenging problem due to the
# shortage of portable tools and issues with LF vs CRLF files - see
# https://gitlab.kitware.com/cmake/cmake/-/issues/16854 for more background on
# this.  We need to address the patch build tool first thing, since any of the
# other ExternalProject_Add builds that follow may depend on it.
###############################################################################
add_subdirectory(patch)

###############################################################################
# Build tools are used during compilation, but are not bundled or distributed
# with binary packages.  We group these tools here for convenience.  Unlike the
# build targets intended for distribution, these outputs are all
# targeted to the extnoinstall subdirectory.
###############################################################################
add_subdirectory(astyle)
add_subdirectory(lief)
add_subdirectory(lemon)
#add_subdirectory(re2c)
#add_subdirectory(perplex)
#add_subdirectory(plief)
#add_subdirectory(strclear)
#add_subdirectory(xmltools)

###############################################################################
# Build logic is broken out per-library, but the ordering is important.  Some
# libraries will depend on others listed here (for example, we want openNURBS
# to use our bundled zlib if it is enabled.) Developers adding, reordering or
# removing dependencies here need to make sure they are aware of impact they
# may be having on other external projects in other files.
###############################################################################

# zlib compression/decompression library
# https://zlib.net
#add_project(zlib GROUPS "BRL-CAD")


# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

