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

# install is the target for projects that will be incorporated into parent
# software binary distributions.  For tools like astyle and plief that are
# build tools only, we instead place them in noinstall.  We need a parent
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

set(BEXT_ROOT bext_output)
set(CMAKE_BUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/${BEXT_ROOT}/install" CACHE PATH "Outputs for bundling" FORCE)
set(CMAKE_NOBUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/${BEXT_ROOT}/noinstall" CACHE PATH "Build tools NOT intended for bundling" FORCE)
file(MAKE_DIRECTORY "${CMAKE_BUNDLE_INSTALL_PREFIX}")
file(MAKE_DIRECTORY "${CMAKE_NOBUNDLE_INSTALL_PREFIX}")

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

macro(TargetDeps proot)
  get_filename_component(dirname ${CMAKE_CURRENT_SOURCE_DIR} NAME)
  if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${dirname}.deps")
    message(FATAL_ERROR "No ${dirname}.deps file found in ${CMAKE_CURRENT_SOURCE_DIR}/")
  endif (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${dirname}.deps")
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/${dirname}.deps" DEP_LINES)
  string(TOLOWER "${proot}" lr)
  foreach(dl ${DEP_LINES})
    set(${proot}_DEPENDS ${${proot}_DEPENDS} ${dl})
    string(TOLOWER "${dl}" ldl)
    # Add the dependency to the dot file
    if (NOT "${ldl}" STREQUAL "patch")
      file(APPEND "${CMAKE_BINARY_DIR}/bext.dot" "\t${lr} -> ${ldl};\n")
    endif (NOT "${ldl}" STREQUAL "patch")
  endforeach(dl ${DEP_LINES})

  # Add these dependencies to the global list
  get_property(ALL_DEPS GLOBAL PROPERTY ALL_DEPENDENCIES)
  set(ALL_DEPS ${ALL_DEPS} ${${proot}_DEPENDS})
  list(SORT ALL_DEPS)
  list(REMOVE_DUPLICATES ALL_DEPS)
  set_property(GLOBAL PROPERTY ALL_DEPENDENCIES ${ALL_DEPS})

  # Set the TARGET variables for CMake generator expression "if" tests
  TargetVars(${proot}_DEPENDS)
endmacro(TargetDeps)

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
    execute_process(
      COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive --depth=1 ${path}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      )
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
      message("Disabling ${pname} due to disabled USE flags")
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
# Applying patch files cross platform is a challenging problem due to the
# shortage of portable tools and issues with LF vs CRLF files - see
# https://gitlab.kitware.com/cmake/cmake/-/issues/16854 for more background on
# this.  We need to address the patch build tool first thing, since any of the
# other ExternalProject_Add builds that follow may depend on it.
###############################################################################
add_project(patch)

###############################################################################
# Although we have bundled flex and bison programs, they can be problematic to
# build - they require working Autotools tool chains (except on Windows where
# we have winflexbison).  We therefore attempt these builds only if we need to.
# This check must come after the patch subdirectory, since if we DO add_project
# the flexbison directory it will need the patch executable.
###############################################################################
if (USE_APPLESEED OR USE_OSPRAY)

  find_package(FLEX)

  if (NOT FLEX_FOUND)
    set(ENABLE_FLEX ON)
  endif (NOT FLEX_FOUND)
  find_package(BISON)

  if (NOT BISON_FOUND)
    set(ENABLE_BISON ON)
  endif (NOT BISON_FOUND)

  if (ENABLE_FLEX OR ENABLE_BISON)
    add_project(flexbison GROUPS "APPLESEED;OSPRAY")
  endif (ENABLE_FLEX OR ENABLE_BISON)

  # Whether or not we actually added the subdirectories, let subsequent targets
  # know we have handled the FLEX and BISON dependencies.  Some will list these
  # as potential build targets, since we may try to compile them, but as the
  # default orientation for these is "build only if we have to" the find
  # process itself needs to satisfy the check.
  set(FLEX_ADDED 1)
  set(BISON_ADDED 1)

endif (USE_APPLESEED OR USE_OSPRAY)

###############################################################################
# Build tools are used during compilation, but are not bundled or distributed
# with binary packages.  We group these tools here for convenience.  Unlike the
# build targets intended for distribution, these outputs are all
# targeted to the noinstall subdirectory.
###############################################################################
add_project(astyle GROUPS "BRLCAD")
add_project(lemon GROUPS "BRLCAD")
add_project(re2c GROUPS "BRLCAD")
add_project(perplex GROUPS "BRLCAD")
add_project(strclear GROUPS "BRLCAD")
add_project(xmltools GROUPS "BRLCAD_EXTRA")  # Used for Docbook building

# RPATH editing - LIEF has the core capabilities, and plief exposes them via
# a command line utility with patchelf compatible options, so we can drop
# either patchelf or plief into our upstream workflows.
add_project(lief GROUPS "BRLCAD")
add_project(plief GROUPS "BRLCAD")

# Keeping this set up for easy turn-on until we're confident plief+LIEF has
# all of our use cases covered - plief is preferred, but we've already hit
# one case where a bug in LIEF had to be fixed.
#add_project(patchelf GROUPS "BRLCAD")

###############################################################################
# Build logic is broken out per-library, but the ordering is important.  Some
# libraries will depend on others listed here (for example, we want openNURBS
# to use our bundled zlib if it is enabled.) Developers adding, reordering or
# removing dependencies here need to make sure they are aware of impact they
# may be having on other external projects in other files.
###############################################################################

# zlib compression/decompression library
# https://zlib.net
add_project(zlib GROUPS "APPLESEED;BRLCAD;OSPRAY")

# zstd - fast lossless compression library
# https://github.com/facebook/zstd
add_project(zstd GROUPS "APPLESEED;OSPRAY")

# minizip-ng - zip manipulation library written in C
# https://github.com/zlib-ng/minizip-ng
add_project(minizip-ng GROUPS "APPLESEED")

# LZ4 - lossless compression algorithm
# https://github.com/lz4/lz4
add_project(lz4 GROUPS "APPLESEED")

# libdeflate fast, whole-buffer DEFLATE-based compression
# https://github.com/ebiggers/libdeflate
add_project(deflate GROUPS "APPLESEED")

# fmt  - formatting library providing an alternative to C++ iostreams
# https://github.com/fmtlib/fmt
add_project(fmt GROUPS "APPLESEED")

# yaml-cpp - YAML parser and emitter in C++ matching the YAML 1.2 spec
# https://github.com/jbeder/yaml-cpp
add_project(yaml-cpp GROUPS "APPLESEED")

# pystring - collection of C++ functions which match the interface and behavior
# of python's string class methods
# https://github.com/imageworks/pystring
add_project(pystring GROUPS "APPLESEED")

# Henry Spencer's regular expression matching library
# https://github.com/BRL-CAD/regex
add_project(regex GROUPS "BRLCAD")

# expat - library for parsing XML 1.0 Fourth Edition
# https://github.com/libexpat/libexpat
add_project(expat GROUPS "APPLESEED")

# International Components for Unicode
# https://github.com/unicode-org/icu
add_project(icu GROUPS "APPLESEED")

# Xerces-C++ - a validating XML parser
# https://xerces.apache.org/xerces-c/
add_project(xerces-c GROUPS "APPLESEED")

# Boost - C++ libraries
# https://www.boost.org
# https://github.com/boostorg/boost
add_project(boost GROUPS "APPLESEED")

# netpbm library - support for pnm,ppm,pbm, etc. image files
# http://netpbm.sourceforge.net/
add_project(netpbm GROUPS "BRLCAD")

# libjpeg-turbo - JPEG image codec
# https://github.com/libjpeg-turbo/libjpeg-turbo
add_project(jpeg GROUPS "APPLESEED;GDAL")

# libpng - Portable Network Graphics image file support
# http://www.libpng.org/pub/png/libpng.html
add_project(png GROUPS "APPLESEED;BRLCAD")

# libtiff - Tag Image File Format (TIFF) support
# https://libtiff.gitlab.io/libtiff/
# https://gitlab.com/libtiff/libtiff
add_project(tiff GROUPS "APPLESEED;GDAL")

# OpenEXR - EXR image storage format
# https://openexr.com/
# https://github.com/AcademySoftwareFoundation/openexr
add_project(openexr GROUPS "APPLESEED")

# UtahRLE - Raster Image library
# https://github.com/BRL-CAD/utahrle
add_project(utahrle GROUPS "BRLCAD")

# OpenColorIO - color management
# https://opencolorio.org
# https://github.com/AcademySoftwareFoundation/OpenColorIO
# Note - the VFX Reference Platform (https://vfxplatform.com/)
# is a useful reference for what versions to expect elements
# of the rendering pipeline software stack to use/require
add_project(opencolorio GROUPS "APPLESEED")

# OpenImageIO - reading and writing images, aimed at VFX studios
# https://github.com/OpenImageIO/oiio
add_project(openimageio GROUPS "APPLESEED")

# ncurses - text-based user interfaces library
# https://invisible-island.net/ncurses/
add_project(ncurses GROUPS "OSPRAY")

# Linenoise - line editing library
# https://github.com/msteveb/linenoise
add_project(linenoise GROUPS "BRLCAD")

# Lightning Memory-Mapped Database
# https://github.com/LMDB/lmdb
add_project(lmdb GROUPS "BRLCAD")

# Eigen - linear algebra library
# https://eigen.tuxfamily.org
add_project(eigen GROUPS "BRLCAD;APPLESEED")

# oneTBB - Threading Building Blocks
# https://github.com/oneapi-src/oneTBB
add_project(onetbb GROUPS "APPLESEED;OSPRAY")

# rkcommon -  C++ infrastructure and CMake utilities
# https://github.com/ospray/rkcommon
add_project(rkcommon GROUPS "OSPRAY")

# LLVM - code generation support
# https://llvm.org/
add_project(llvm GROUPS "APPLESEED;OSPRAY")

# ISPC - Implicit SPMD Program Compiler
# https://ispc.github.io
# https://github.com/ispc/ispc
add_project(ispc GROUPS "OSPRAY")

# STEPcode - support for reading and writing STEP files
# https://github.com/stepcode/stepcode
add_project(stepcode GROUPS "BRLCAD_EXTRA")

# SQLITE3 - embeddable database
# https://www.sqlite.org
add_project(sqlite3 GROUPS "GDAL")

# PROJ - generic coordinate transformation
# https://proj.org
add_project(proj GROUPS "GDAL")

# GDAL -  translator library for raster and vector geospatial data formats
# https://gdal.org
add_project(gdal GROUPS "GDAL")

# pugixml - a light-weight C++ XML processing library
# https://pugixml.org/
add_project(pugixml GROUPS "BRLCAD;APPLESEED")

# Open Asset Import Library - library for supporting I/O for a number of
# Geometry file formats
# https://github.com/assimp/assimp
add_project(assetimport GROUPS "BRLCAD")

# OpenCV - Open Source Computer Vision Library
# http://opencv.org
add_project(opencv GROUPS "BRLCAD_EXTRA")

# OpenMesh Library - library for representing and manipulating polygonal meshes
# https://www.graphics.rwth-aachen.de/software/openmesh/
add_project(openmesh GROUPS "BRLCAD_EXTRA")

# Manifold Library - used for performing boolean ops on meshes
# https://github.com/elalish/manifold
add_project(manifold GROUPS "BRLCAD")

# openNURBS - Non-Uniform Rational BSpline library
# https://github.com/mcneel/opennurbs
add_project(opennurbs GROUPS "BRLCAD")

# OSMesa - Off Screen Mesa Rendering Library
# https://github.com/starseeker/osmesa
add_project(osmesa GROUPS "BRLCAD")

# Poly2Tri - constrained Delaunay triangulation
# https://github.com/jhasse/poly2tri
add_project(poly2tri GROUPS "BRLCAD")

# Geogram - a programming library with geometric algorithms
# https://github.com/BrunoLevy/geogram
add_project(geogram GROUPS "BRLCAD_EXTRA")

# Open Shading Language (OSL) - language for programmable shading
# https://github.com/AcademySoftwareFoundation/OpenShadingLanguage
#
# TODO - need to check if https://github.com/lexxmark/winflexbison will
# work for Windows for OSL's usage of flex/bison...
add_project(osl GROUPS "APPLESEED")

# Embree raytracing kernel
# https://github.com/embree/embree
add_project(embree GROUPS "APPLESEED;OSPRAY")

# TCL - scripting language.  For Tcl/Tk builds we want
# static lib building on so we get the stub libraries.
# https://www.tcl.tk
set(TCL_ENABLE_TK ON CACHE BOOL "enable tk")
add_project(tcl GROUPS "TCL")
add_project(tk GROUPS "TCL")
add_project(itcl GROUPS "TCL")
add_project(itk GROUPS "TCL")
add_project(iwidgets GROUPS "TCL")
add_project(tkhtml GROUPS "TCL")
add_project(tktable GROUPS "TCL")

# Qt - cross-platform user interface/application development toolkit
# https://download.qt.io/archive/qt
add_project(qt GROUPS "QT")

# Appleseed - global illumination rendering engine
# https://github.com/appleseedhq/appleseed
add_project(appleseed GROUPS "APPLESEED")

# OSPRay - ray tracing engine
# https://github.com/ospray/OSPRay
add_project(ospray GROUPS "OSPRAY")


# Warn the user if the settings changed in a way the indicate there is
# a risk of now-disabled build products in the output directory
if (EXISTS "${CMAKE_BUNDLE_INSTALL_PREFIX}" AND STALE_INSTALL_WARN)
  file(GLOB OFILES_BIN LIST_DIRECTORIES TRUE ${CMAKE_BUNDLE_INSTALL_PREFIX}/bin/* )
  file(GLOB OFILES_LIB LIST_DIRECTORIES TRUE ${CMAKE_BUNDLE_INSTALL_PREFIX}/lib/* )
  if (OFILES_BIN OR OFILES_LIB)
    message(WARNING "\nBuild settings have changed, but build outputs are already present in ${CMAKE_BUNDLE_INSTALL_PREFIX}.  Recommend clearing the directory to avoid unexpected files being present when using the build outputs to support compilation.\n")
  endif (OFILES_BIN OR OFILES_LIB)
endif (EXISTS "${CMAKE_BUNDLE_INSTALL_PREFIX}" AND STALE_INSTALL_WARN)

# Close out dependencies DOT file
file(APPEND "${CMAKE_BINARY_DIR}/bext.dot" "\n}\n")

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

