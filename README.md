# bext - External Dependencies Management

This repository manages the building of dependencies used by large scale computer graphics projects, with a primary focus on the [BRL-CAD](https://github.com/BRL-CAD/brlcad) computer aided design system.

# Quick start

* Clone this repository
```sh
git clone https://github.com/BRL-CAD/bext
```
(This should be fast - by default most of the downloading happens during the configure process.)
* Make a build directory
```sh
mkdir bext_build && cd bext_build
```
* Configure with CMake.  Individual components can be enabled or disabled, but the ENABLE_ALL flag is used to automatically turn on all the projects.  There are also USE_* variables that can enable or disable various groupings of components based on which specific application stacks the user wishes to support.
```sh
cmake ../bext -DENABLE_ALL=ON
```
* Run the build process.
```sh
cmake --build . --config Release --parallel 8
```

Note that if you know you are going to build most or all of the component projects you can immediately populate all submodules when performing the clone:

```sh
git clone --recursive https://github.com/BRL-CAD/bext
```

This is primarily useful if you want to do all the downloading at once up front or you are preparing to work in an environment without an internet connection.

A word of caution - full cloning of all the repository contents can be time, bandwidth and space intensive.  To help alleviate this a bit, you can add -DGIT_SHALLOW_CLONE=ON to the CMake configure, or if you're pre-cloning all repositories ahead of time use --depth=1 option with the above recursive clone.  Be aware that shallow clones have some limitations that make them unsuitable for much other than compiling (updating to newer versions of submodules won't work, for example) so shallow clones aren't recommended for development.

# USE_* Options

A complete ENABLE_ALL build of all components in this repository is a *very* large build, and developers not needing some subset of the components may wish to avoid paying the price of building *all* submodules.  That is why the USE_* options are defined - ENABLE_ALL will only enable those submodules that indicate they are used by at least one active USE_* option.  By default, USE_BRLCAD, USE_BRLCAD_EXTRA, USE_GDAL and USE_TCL are enabled as they collectively define the most common set of dependencies used by a standard BRL-CAD build.  However, if a developer is building BRL-CAD without terrain support and without Tcl/Tk support, setting USE_GDAL and USE_TCL to OFF will skip compilation of those submodules.  Available USE_* options are:

* USE_BRLCAD - Core BRL-CAD dependencies always needed to build BRL-CAD successfully.
* USE_BRLCAD_EXTRA - Optional BRL-CAD dependencies.
* USE_GDAL - Geospatial Data Abstraction Library and dependencies
* USE_TCL - Tcl/Tk and associated packages
* USE_QT - Qt - cross-platform software for creating graphical user interfaces
* USE_APPLESEED - Physically-based global illumination rendering engine
* USE_OSPRAY - Intel high performance ray tracing engine

(For BRL-CAD components specifically, a more nuanced enable/disable decision can be made if the BRLCAD_COMPONENTS variable is set.  If the parent BRL-CAD build is only building a subset of the BRL-CAD target set, not all dependencies will be needed.)

# Using the Build Outputs with BRL-CAD

At the moment this repository and BRL-CAD's support of it are still experimental.
To test it, the steps are as follows:

* Clone the BRL-CAD repository
```sh
git clone https://github.com/BRL-CAD/brlcad
```
* Remove the internal 3rd party directories (be sure NOT to accidentally commit this change to the repository...)
```sh
cd brlcad && rm -rf misc/tools/ext src/other
```
* Make a build directory
```sh
cd .. && mkdir brlcad_exttest_build && cd brlcad_exttest_build
```
* Configure with CMake, specifying the path holding the bext output directory the BRLCAD_EXT_DIR variable to locate bext_output. Unless you have overridden the CMAKE_INSTALL_PREFIX of the bext build, it will be located in your home directory.  The bext_output directory should in turn contain install and noinstall folders.  If you also wish to test with Qt, you must currently enable that support in BRL-CAD as well.  (Note that the BRL-CAD configure process is responsible for staging the BRLCAD_EXT_DIR contents into the build directory, so it can take some time to complete...)
```sh
cmake ../brlcad -DBRLCAD_EXT_DIR=<your_bext_output_dir> -DBRLCAD_ENABLE_QT=ON
```
* Run the build process.
```sh
cmake --build . --config Release --parallel 8
cmake --build . --target package --parallel 8
```

If all goes well, the final result should be a relocatable BRL-CAD archive
including both the main BRL-CAD outputs and the products of this external
dependencies repository.


# About This Repository

In broad, the structure of the source tree is two tiered - the top level directories each denote a specific dependency project (Tcl, Qt, GDAL, etc.).  Within that directory are found:

* A reference (using git submodules) to a copy of the upstream source code
* Our managing CMakeLists.txt file defining the logic for building that project
* A <dirname>.deps file identifying a project's dependencies on other bext projects
* Any patch files or other supporting resources not part of the upstream tree

Sometimes third party libraries will depend on other third party libraries (for example, libpng's use of zlib) - when a bundled component that is a dependency of other bundled projects is enabled, the expectation is that the other bundled components will use our copy rather than system copies of those libraries.

# Compilation-Only Tools

Although most of the components here are intended for bundling with the eventual binary software distribution, there are some exceptions to that rule. A few of the projects (AStyle, patch, LIEF, etc.) target a different installation folder and are used only for compilation (for this repository and/or when bundling the results of building this repository with other applications.)

There are also header-only "libraries" such as Eigen that are needed only for compilation, and do not need to be distributed with our packages.

To figure out which projects are in these categories, check for a CMAKE_NOBUNDLE_INSTALL_PREFIX target being used by their top level CMakeLists.txt file managing the ExternalProject_Add build definition.

