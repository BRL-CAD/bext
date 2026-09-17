# Xmin-backed bundled toolkits

Xmin is a small, self-contained X11 server and client library - see
https://github.com/starseeker/Xmin

An installed Xmin SDK can provide the X11 and OpenGL surface for bext's
bundled Tk and Qt, allowing fully interactive automated GUI application testing
in an environment that has neither X nor OpenGL.

Set `BEXT_XMIN_ROOT` to select the standard Xmin profile:

```sh
cmake -S /path/to/bext -B /path/to/bext-build \
  -DBEXT_XMIN_ROOT=/absolute/path/to/xmin-sdk \
  -DENABLE_TCL=ON -DENABLE_QT=ON
```

The profile affects only Tk and Qt packages selected for a local build.  It
does not enable a package excluded by `USE_*`, `BRLCAD_COMPONENTS`, or an
explicit `DISABLE_*` setting.

* Tk is configured with `--with-xmin` and bext's matching Tk patch.
* Qt is built with the matching Xmin patch, the qxcb desktop-OpenGL profile,
  and dependency audits that reject accidental host X11 or OpenGL linkage.

The patches are maintained next to the dependency build logic as
`tk/tk_xmin.patch` and `qt/qt_xmin.patch`.  They are tied to the exact Tk
and Qt submodule revisions in this repository.  Updating either dependency
therefore requires updating its patch; a stale patch fails during the patch
step rather than silently producing a mixed build.

The Xmin SDK must include toolkit-client support for Tk.  Qt additionally
requires the Qt X11 compatibility client and client OpenGL support.  Normal
system discovery is unchanged when `BEXT_XMIN_ROOT` is empty.

Qt's installed package metadata retains an explicit dependency on Xmin.
Downstream projects must therefore keep the same SDK discoverable with
`Xmin_DIR` or `CMAKE_PREFIX_PATH`; configuration fails instead of falling back
to host X libraries when that SDK is absent.

## Advanced toolkit patch controls

Unix builds may pass additional, semicolon-separated absolute patch paths in
`TK_EXTRA_PATCHES`, plus additional Tk `configure` arguments in
`TK_CONFIGURE_ARGS`.  `QT_EXTRA_PATCHES` provides the corresponding Qt
hook.  `QT_XMIN_ROOT` remains available for manually supplied Qt Xmin patches.
These low-level controls are not needed when `BEXT_XMIN_ROOT` selects the
standard profile.
