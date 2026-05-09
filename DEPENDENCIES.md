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
| `geogram` | `USE_BRLCAD` | `install` | Geometry algorithm library. |
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
