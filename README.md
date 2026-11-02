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

# Optional bootstrap

If you want to fetch a given profile's source submodules up front
instead of letting configure fetch them on demand:

```sh
cmake -DPROFILE=auto -P CMake/BextBootstrap.cmake
cmake --preset auto
```

Use `LIST_ONLY=ON` to preview the selected submodules without fetching them,
and `GIT_SHALLOW_CLONE=ON` to specify shallow clones during bootstrap.

Both configure and bootstrap accept `BEXT_REPOSITORY_ROOT` for an alternate
repository root and `BEXT_GIT_REMAP=/path/to/mirrors.txt` for a reusable list of
per-dependency mirrors or upstreams.  Start with the commented
[mapping template](CMake/BextGitRemap.example).  See [alternate repositories and
offline mirrors](INSTALL.md#alternate-repositories-and-offline-mirrors) for
examples and inline overrides.

# How manual selection works

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

# Experimental dependencies

When a dependency is being evaluated, sometimes it will be given a preliminary
directory without setting up a submodule.  Testing will then take place using
local source snapshots - this avoids having bext history depend on a repo
SHA1 before we're sure we need it, but gives us a place to store patch files
and build logic that are needed to properly build it as part of bext.

Within `USE_BRLCAD_EXTRA`, each wrapper enables its build when the source is
present and disables it when absent. No checkout or download is attempted.

If the decision is made to incorporate such a dependency, its submodule will
be added and it will become part of the "regular" bext setup.

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
* `bext-install-manifest.json` - relative file classifications and the
  platform metadata and producer install prefixes needed by downstream
  staging builds

The normal build finalizes bundled binaries after all dependency install steps.
It uses `strclear` and, where available, `plief` to remove stale build paths and
normalize RPATH-bearing files before writing the manifest.  Consumers should
continue to treat `install/` as read-only and perform their own staging-specific
path and RPATH edits on copied files.

Source, build, and install directories may use symlink aliases.  The manifest's
`install_prefixes` array records both the requested and physical install roots,
so BRL-CAD can replace embedded paths even when it accesses the bundle through
a different alias or after the bundle has moved.  Rebuild `strclear` and finalize
the bundle after updating from a version that required physical paths.

The ELF integration regression builds a shared library and executable, finalizes
a bundle, moves it, and runs BRL-CAD's staging and install processing.  It requires
CMake, Ninja, a C compiler, and built copies of both helper tools:

```sh
cmake -DBRLCAD_SOURCE=../brlcad \
  -DSTRCLEAR=build/noinstall/bin/strclear -DPLIEF=build/noinstall/bin/plief \
  -P tests/symlink_paths.cmake
```

The normal build also generates a dependency graph in the build directory as
`bext.dot`.  When Graphviz `dot` is available, the build also emits rendered
forms such as `bext.svg`, `bext.png`, and `bext.pdf`.

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
* [XMIN.md](XMIN.md) - testing-only headless X11 support using Xmin
