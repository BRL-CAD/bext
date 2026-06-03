# bext - External Dependencies for BRL-CAD

`bext` builds third-party libraries and helper tools used by
[BRL-CAD](https://github.com/BRL-CAD/brlcad).  By default it prefers suitable
system packages and builds local copies only when they are needed.

# Quick start

Clone the repository, configure with the official `auto` preset, and build:

```sh
git clone https://github.com/BRL-CAD/bext
cd bext
cmake --preset auto
cmake --build build/auto --config Release --parallel 8
```

Submodules are populated on demand during configure.  For checkout and
platform setup details, see [INSTALL.md](INSTALL.md).

The preset workflow relies on CMake's newer preset support.  If you are using
CMake 3.19 or 3.20, use the raw configure equivalents below.

# How selection works

Build selection happens in three layers:

1. `USE_*` options decide which dependency families are in scope.
2. For in-scope packages, the default behavior is to use a suitable system
   package if one is found and build a local copy only when needed.
3. `ENABLE_<pkg>=ON` or `OFF` overrides one package explicitly.

Default `USE_*` values:

* `USE_BRLCAD=ON`
* `USE_BRLCAD_EXTRA=ON`
* `USE_GDAL=ON`
* `USE_QT=ON`
* `USE_TCL=ON`
* `USE_APPLESEED=OFF`
* `USE_OSPRAY=OFF`

`ENABLE_ALL=ON` changes step 2 by preferring local builds for packages in the
active `USE_*` groups.  It does not turn on groups whose `USE_*` option is
`OFF`.

When `bext` is driven from a BRL-CAD build, `BRLCAD_COMPONENTS` can further
narrow some BRL-CAD-related packages to only those needed by the requested
component set.

# Official profiles

The supported configure entry points are:

* `auto` - standard BRL-CAD-oriented profile using suitable system packages
  when found
* `bundled` - standard BRL-CAD-oriented profile with bundled/local builds
  preferred for all active groups
* `minimal` - core BRL-CAD profile without extras, GDAL, Qt, Tcl/Tk,
  Appleseed, or OSPRay
* `everything` - all current groups enabled with bundled/local builds
  preferred throughout

Use them like this:

```sh
cmake --preset auto
cmake --preset bundled
cmake --preset minimal
cmake --preset everything
```

Build using the preset's build directory:

```sh
cmake --build build/auto --config Release --parallel 8
```

# Raw configure equivalents

`auto`:

```sh
cmake ../bext -DCMAKE_BUILD_TYPE=Release
```

`bundled`:

```sh
cmake ../bext -DENABLE_ALL=ON -DCMAKE_BUILD_TYPE=Release
```

`minimal`:

```sh
cmake ../bext \
  -DUSE_BRLCAD_EXTRA=OFF \
  -DUSE_GDAL=OFF \
  -DUSE_QT=OFF \
  -DUSE_TCL=OFF \
  -DCMAKE_BUILD_TYPE=Release
```

`everything`:

```sh
cmake ../bext \
  -DENABLE_ALL=ON \
  -DUSE_APPLESEED=ON \
  -DUSE_OSPRAY=ON \
  -DCMAKE_BUILD_TYPE=Release
```

# Build outputs

By default, `CMAKE_INSTALL_PREFIX` is the build directory.  `bext` creates two
output trees under that prefix:

* `install/` - files intended to be bundled with downstream software
* `noinstall/` - build-only tools and compile-time-only assets

When BRL-CAD consumes a `bext` build, `BRLCAD_EXT_DIR` should point at the
parent directory containing both `install/` and `noinstall/`.

# Using the build outputs with BRL-CAD

If you used the `auto` preset, `BRLCAD_EXT_DIR` should be `../bext/build/auto`.
Configure BRL-CAD with:

```sh
git clone https://github.com/BRL-CAD/brlcad
mkdir brlcad_build
cd brlcad_build
cmake ../brlcad -DBRLCAD_EXT_DIR=../bext_build -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release --parallel 8
```

If you built Qt in `bext`, also enable Qt in BRL-CAD:

```sh
cmake ../brlcad \
  -DBRLCAD_EXT_DIR=../bext_build \
  -DBRLCAD_ENABLE_QT=ON \
  -DCMAKE_BUILD_TYPE=Release
```

# More information

* [INSTALL.md](INSTALL.md) - platform prerequisites, checkout options, and
  setup caveats
* [DEPENDENCIES.md](DEPENDENCIES.md) - package-to-group reference, output
  classification, and dependency addition workflow
* [NOTES.md](NOTES.md) - maintainer notes and submodule procedures
