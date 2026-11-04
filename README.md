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

`USE_BRLCAD` now includes STEPcode, OpenVDB, OpenCV, and Bullet. The former
`USE_BRLCAD_EXTRA` option has been removed; values left in an existing cache
or passed on the command line no longer control those packages. To skip their
local builds individually, use `ENABLE_STEPCODE=OFF`, `ENABLE_OPENVDB=OFF`,
`ENABLE_OPENCV=OFF`, and `ENABLE_BULLET=OFF`.

# Experimental dependencies

When a dependency is being evaluated, sometimes it will be given a preliminary
directory without setting up a submodule.  Testing will then take place using
local source snapshots. This lets us evaluate the source before adding a
submodule, while giving us a place to store the patch files and build logic
needed to build it as part of bext.

Register an experimental wrapper under the appropriate active `USE_*` group
(usually `BRLCAD`) and use `bext_local_source(...)` to declare its source path,
repository URL, and full commit ID. The wrapper builds the snapshot when its
`CMakeLists.txt` is present and skips it when absent, even with `ENABLE_ALL=ON`.
`ENABLE_<pkg>=OFF` or `DISABLE_<pkg>=ON` prevents the local build. The cached
`ENABLE_<pkg>` preference is preserved when a snapshot is temporarily absent,
so placing the source later enables it on the next configure unless explicitly
disabled. No checkout or download is attempted, and bootstrap excludes these
wrappers from its submodule list. The declared URL and revision supply
provenance for the dependency table and SBOM without a `.gitmodules` entry.

If the decision is made to incorporate such a dependency, its submodule will
be added and it will become part of the "regular" bext setup. See the
[pugixml walkthrough](NOTES.md#example-pugixml-from-local-snapshot-to-submodule)
for both stages.

# Official profiles

The supported configure entry points are:

* `auto` - standard BRL-CAD-oriented profile using suitable system packages
  when found
* `bundled` - standard BRL-CAD-oriented profile with bundled/local builds
  preferred for all active groups
* `minimal` - BRL-CAD dependency group without GDAL, Qt, Tcl/Tk,
  Appleseed, or OSPRay
* `everything` - all current groups enabled with bundled/local builds
  preferred throughout

`minimal` includes STEPcode, OpenVDB, OpenCV, and Bullet through `USE_BRLCAD`.
Use the individual `ENABLE_<pkg>=OFF` overrides above if those local builds
are not wanted.

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

# Resource and disk limits

Dependency compilation defaults to at most two jobs, with one concurrent link.
Set `BEXT_BUILD_JOBS` and `BEXT_LINK_JOBS` to change those limits. Ninja builds
share its global console pool for dependency configure, build, and install
steps, so an unrestricted outer `ninja` cannot launch several expensive
dependency builds simultaneously. Each CMake dependency also receives compile
and link pools; Qt and non-CMake wrappers use the same compilation limit.
With other generators, use `cmake --build ... --parallel 1` to limit outer
dependency concurrency as well.

For CI and builds on small disks, use a fresh build directory with
`BEXT_DISCARD_WORK=ON`:

```sh
cmake --preset bundled -B build/compact \
  -DBEXT_DISCARD_WORK=ON -DBEXT_BUILD_JOBS=2 -DBEXT_LINK_JOBS=1 \
  -DCMAKE_INSTALL_PREFIX="$PWD/out/compact"
cmake --build build/compact --parallel 1
```

This mode builds one dependency at a time and deletes its generated source
copy and compilation directory only after a successful install. Tcl/Tk/Itcl/Itk
working trees remain until finalization. Original dependency checkouts,
installed outputs, ExternalProject control files, and logs are retained.
The install prefix can also remain at its default inside the build directory.
LLVM's own working tree must still fit on disk while LLVM is being built.

Repeat the build command to resume a failed build with the same inputs;
completed dependencies are skipped, and failed working trees remain available
for diagnosis. Logs are in `build/compact/bext-release-logs`, and available disk
space is reported after each successful dependency. Changes to sources,
configuration, toolchain flags, or job limits require a fresh build directory
and install prefix. Completed installed files must remain intact. This is a
build-time option; leave it off for ordinary incremental development.
With Ninja and Makefile generators, `clean` resets the recorded completion
state so the next build can reconstruct all dependencies.

The offline integration tests compile small dependencies and exercise cleanup,
failure recovery, deferred cleanup, input changes, and resource pools:

```sh
python3 CMake/tests/test_release_build.py -v
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
a bundle, moves it, and runs BRL-CAD's staging and install processing. It also
checks a pkg-config-based Find module through BRL-CAD's package wrapper, then
builds and runs its consumer. It requires CMake, Ninja, a C compiler, pkg-config,
and built copies of both helper tools:

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
