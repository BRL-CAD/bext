# bext - External Dependencies Management

This repository manages the building of dependencies used by large scale computer graphics projects, with a primary focuse on the [BRL-CAD](https://github.com/BRL-CAD/brlcad) computer aided design system.

# Quick start

* Clone this repository
```sh
git clone https://github.com/starseeker/bext
```

Note - if you know you are going to build most or all of the component projects you can immediately populate all submodules when performing the clone:

```sh
git clone --recurse-submodules https://github.com/starseeker/bext
```

If you don't recurse through submodules when cloning, the configure step will populate those submodule directories needed based on the build settings.

* Make a build directory
```sh
mkdir bext_build && cd bext_build
```
* Configure with CMake.  Individual components can be enabled or disabled, but the ENABLE_ALL flag is used to automatically turn on all the projects.  There are also USE_* variables that can enable or disable various groupings of componentsbased on which specific application stacks the user wishes to support.
```sh
cmake ../bext -DENABLE_ALL=ON
```
* Run the build process.
```sh
cmake --build . --config Release --parallel 8
```

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
* Configure with CMake.  If no custom CMAKE_INSTALL_PREFIX was supplied to the bext build, BRL-CAD will know to look for the folder it needs in the user's home directory. If a custom location was used, specify the path holding the brlcad_ext output directory using -DBRLCAD_EXT_DIR=<your_root> (brlcad_ext should in turn contain the extinstall and extnoinstall folders.)  If you also wish to test with Qt, you must currently enable that support in BRL-CAD as well.  (Note that the BRL-CAD configure process is responsible for staging the BRLCAD_EXT_DIR contents into the build directory, so it can take some time to complete...)
```sh
cmake ../brlcad -DBRLCAD_ENABLE_QT=ON
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

In broad, the structure of the source tree is two tiered - the top level directories
each denote a specific dependency project (Tcl, Qt, GDAL, etc.).  Within that
directory are found:

* A reference to a copy of the upstream source code
* Our managing CMakeLists.txt file defining the logic for building that project
* Any patch files or other supporting resources not part of the upstream build.

Sometimes third party libraries will depend on other third party libraries (for
example, libpng's use of zlib) - when a bundled component that is a dependency
of other bundled projects is enabled, the expectation is that the other bundled
components will use our copy rather than system copies of those libraries.

# Compilation-Only Tools

Although most of the components here are intended for bundling with the
eventual binary software distribution, there are some exceptions to that rule.
A few of the projects (AStyle, patch, LIEF, etc.) target a different
installation folder and are used only for compilation (for this repository
and/or when bundling the results of building this repository with other
applications.)

There are also header-only "libraries" such as Eigen that are needed only for
compilation, and do not need to be distributed with our packages.

To figure out which projects are in these categories, check for a
CMAKE_NOBUNDLE_INSTALL_PREFIX target being used by their top level
CMakeLists.txt file managing the ExternalProject_Add build definition.

