# bext - Dependency Reference

This file is a package map for `bext`.  It shows which `USE_*` groups can bring
each project into scope and whether its outputs land in `install/` or
`noinstall/`.

A package listed here may still use a system installation instead of building a
local copy unless `ENABLE_ALL=ON` or `ENABLE_<pkg>=ON` is used.

For some BRL-CAD-related packages, `BRLCAD_COMPONENTS` can narrow the final
selection further.

# Output types

* `install` - bundled output intended for downstream use
* `noinstall` - build-only tool or compile-time-only asset

# Projects

| Project | `USE_*` group(s) | Output | Notes |
| --- | --- | --- | --- |
| `patch` | always considered | `noinstall` | Helper tool.  Built only when a suitable system `patch` is unavailable, or when `ENABLE_ALL=ON`. |
| `flexbison` | `USE_APPLESEED`, `USE_OSPRAY` | `noinstall` | Helper tool.  Added only when those stacks are enabled and system `flex` or `bison` is missing. |
| `astyle` | `USE_BRLCAD` | `noinstall` | Build-time helper tool. |
| `assetimport` | `USE_BRLCAD` | `install` | Assimp-based geometry import support. |
| `appleseed` | `USE_APPLESEED` | `install` | Top-level Appleseed renderer. |
| `boost` | `USE_APPLESEED` | `install` | Appleseed dependency. |
| `bullet` | `USE_BRLCAD_EXTRA` | `install` | Optional BRL-CAD dependency. |
| `clipper2` | `USE_BRLCAD` | `install` | Polygon clipping and offsetting. |
| `deflate` | `USE_APPLESEED` | `install` | Compression library. |
| `eigen` | `USE_BRLCAD`, `USE_APPLESEED` | `noinstall` | Header-only, compile-time-only dependency. |
| `embree` | `USE_APPLESEED`, `USE_OSPRAY` | `install` | Ray tracing kernel used by rendering stacks. |
| `expat` | `USE_APPLESEED` | `install` | XML parser. |
| `fmt` | `USE_APPLESEED` | `install` | Formatting library. |
| `gdal` | `USE_GDAL` | `install` | Top-level GDAL library. |
| `gte` | `USE_BRLCAD` | `noinstall` | GeometricTools content used at build time. |
| `icu` | `USE_APPLESEED` | `install` | Unicode support. |
| `ispc` | `USE_OSPRAY` | `install` | ISPC compiler used by OSPRay-related builds. |
| `itcl` | `USE_TCL` | `install` | Tcl extension package. |
| `itk` | `USE_TCL` | `install` | Tk extension package. |
| `iwidgets` | `USE_TCL` | `install` | Tcl/Tk widget package. |
| `jpeg` | `USE_APPLESEED`, `USE_BRLCAD`, `USE_GDAL` | `install` | JPEG codec support. |
| `lemon` | `USE_BRLCAD` | `noinstall` | Build-time parser generator support. |
| `lief` | `USE_BRLCAD` | `noinstall` | Build-time helper for binary/rpath work. |
| `llvm` | `USE_APPLESEED`, `USE_OSPRAY` | `install` | Compiler infrastructure. |
| `lmdb` | `USE_BRLCAD` | `install` | LMDB database library. |
| `lz4` | `USE_APPLESEED` | `install` | Compression library. |
| `manifold` | `USE_BRLCAD` | `install` | Mesh boolean operations. |
| `minizip-ng` | `USE_APPLESEED` | `install` | Zip manipulation library. |
| `mmesh` | `USE_BRLCAD` | `install` | Mesh processing library. |
| `ncurses` | `USE_OSPRAY` | `install` | Text UI dependency used by the OSPRay stack. |
| `netpbm` | `USE_BRLCAD` | `install` | Netpbm image format support. |
| `onetbb` | `USE_APPLESEED`, `USE_OSPRAY` | `install` | oneTBB threading library. |
| `opencv` | `USE_BRLCAD_EXTRA` | `install` | Optional BRL-CAD dependency. |
| `opencolorio` | `USE_APPLESEED` | `install` | Color management library. |
| `openexr` | `USE_APPLESEED` | `install` | OpenEXR image support. |
| `openimageio` | `USE_APPLESEED` | `install` | Image I/O library. |
| `opennurbs` | `USE_BRLCAD` | `install` | NURBS support. |
| `osl` | `USE_APPLESEED` | `install` | Open Shading Language. |
| `osmesa` | `USE_BRLCAD` | `install` | Off-screen Mesa rendering. |
| `ospray` | `USE_OSPRAY` | `install` | Top-level OSPRay renderer. |
| `perplex` | `USE_BRLCAD` | `noinstall` | Build-time parser tool support. |
| `plief` | `USE_BRLCAD` | `noinstall` | Build-time command-line wrapper around LIEF functionality. |
| `png` | `USE_APPLESEED`, `USE_BRLCAD` | `install` | PNG image support. |
| `poissonrecon` | `USE_BRLCAD` | `noinstall` | Build-time Poisson reconstruction support. |
| `proj` | `USE_GDAL` | `install` | Coordinate transformation library. |
| `pugixml` | `USE_BRLCAD`, `USE_APPLESEED` | `install` | XML processing library. |
| `pystring` | `USE_APPLESEED` | `install` | Python-style string utilities. |
| `qt` | `USE_QT` | `install` | Builds Qt 6 and QtSvg. |
| `re2c` | `USE_BRLCAD` | `noinstall` | Build-time lexer generator support. |
| `regex` | `USE_BRLCAD` | `install` | Regular expression library. |
| `rkcommon` | `USE_OSPRAY` | `install` | Common infrastructure library for OSPRay. |
| `sqlite3` | `USE_GDAL` | `install` | SQLite dependency for the GDAL stack. |
| `stepcode` | `USE_BRLCAD_EXTRA` | `install` | STEP file support. |
| `strclear` | `USE_BRLCAD` | `noinstall` | Build-time helper tool. |
| `tcl` | `USE_TCL` | `install` | Tcl runtime and development files. |
| `tiff` | `USE_APPLESEED`, `USE_GDAL` | `install` | TIFF image support. |
| `tinygltf` | `USE_BRLCAD` | `install` | glTF support. |
| `tk` | `USE_TCL` | `install` | Tk runtime and development files. |
| `tkhtml` | `USE_TCL` | `install` | Tcl/Tk HTML widget. |
| `tktable` | `USE_TCL` | `install` | Tcl/Tk table widget. |
| `xerces-c` | `USE_APPLESEED` | `install` | XML parser used by the Appleseed stack. |
| `xmltools` | `USE_BRLCAD_EXTRA` | `noinstall` | Build-time XML/docbook helper tools. |
| `yaml-cpp` | `USE_APPLESEED` | `install` | YAML parser and emitter. |
| `zlib` | `USE_APPLESEED`, `USE_BRLCAD`, `USE_OSPRAY` | `install` | Compression library shared by multiple stacks. |
| `zstd` | `USE_APPLESEED`, `USE_OSPRAY` | `install` | Compression library shared by rendering stacks. |

# Notes

* `install/` versus `noinstall/` is about downstream use, not importance.
  Several `noinstall` entries are essential build helpers.
* `ENABLE_ALL=ON` does not add `USE_APPLESEED` or `USE_OSPRAY` by itself.
  Those groups still need to be enabled explicitly.
* A few source trees, such as `patchelf`, are present in the repository but are
  not currently added by the top-level build.

# Adding a dependency

For maintainers, the high-level workflow for adding a new dependency to `bext`
is:

1. Decide whether the dependency belongs in `bext` at all.
Only add repositories that are expected to support live BRL-CAD or related
build features.  Exploratory work that may be discarded should stay in a branch
until the dependency choice is settled.

2. Prepare the BRL-CAD-hosted source repository first.
`bext` generally points at BRL-CAD-managed copies of upstream sources rather
than upstream repositories directly.  Before wiring anything into `bext`, make
sure the BRL-CAD copy has the intended `RELEASE` content, submodules handled as
needed, and license files available for installation.

3. Choose the `USE_*` group or groups that should bring the dependency into
scope.
This controls when the dependency is considered at all.  If none of the
existing groups fit, add a new one only if it represents a real build profile
that users can reason about.

4. Add the new top-level directory and git submodule.
The directory should usually contain:
* the upstream source as a git submodule
* a managing `CMakeLists.txt`
* a `<name>.deps` file listing other `bext` projects it depends on
* any patch files or helper resources needed by the build

After `git submodule add`, update `.gitmodules` to include `ignore = dirty` for
the new entry, consistent with the existing submodules.

5. Add the build logic.
Follow the patterns used by nearby dependencies:
* use `git_submodule_init(...)`
* use `RegisterDeps(...)`
* decide whether the outputs belong in `install` or `noinstall`
* copy license files into `${DOC_LICENSE_DIR}`
* use `bext_enable(...)`, `cad_enable(...)`, or custom logic as needed to
  respect system detection and BRL-CAD component selection

6. Register the dependency in the top-level build.
Add `add_project(...)` to the top-level `CMakeLists.txt` in dependency order so
that any prerequisites appear earlier in the file.

7. Update the docs.
At minimum:
* add the project to this file
* update `INSTALL.md` if the new dependency adds system prerequisites
* update `NOTES.md` if the dependency needs special submodule or maintainer
  handling

8. Test the intended selection behavior and build flow.
Check at least:
* the default configure path for the relevant `USE_*` groups
* `-DENABLE_ALL=ON`
* any new or changed prerequisite detection
* downstream use if the outputs are intended for BRL-CAD bundling

9. Only after the dependency is working, commit the new submodule reference and
the `bext` integration together.
That keeps the repository history aligned with a working configuration rather
than a partial experiment.

For lower-level git and submodule procedures, see [NOTES.md](NOTES.md).
