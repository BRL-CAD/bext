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

# Clipper2 - A Polygon Clipping and Offsetting library
# https://github.com/AngusJohnson/Clipper2
add_project(clipper2 GROUPS "BRLCAD")

# GeometricTools - a collection of geometry algorithms.
# https://github.com/davideberly/GeometricTools
add_project(gte GROUPS "BRLCAD")

# Adaptive Multigrid Solvers - Poisson Surface Reconstruction code.
# https://github.com/mkazhdan/PoissonRecon
#add_project(poissonrecon GROUPS "BRLCAD")

# mmesh - mesh decimation and processing library.
# https://github.com/BRL-CAD/mmesh
add_project(mmesh GROUPS "BRLCAD")

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

# Geogram - a programming library with geometric algorithms
# https://github.com/BrunoLevy/geogram
add_project(geogram GROUPS "BRLCAD")

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

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8

