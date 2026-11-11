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
* Tktable uses the X11 link flags exported by that Tk, preserving the same
  client ABI for the extension.
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

## Tktable development and tests

Tktable is pinned to the upstream 2.12.2 release through the BRL-CAD fork.
Unix builds use its TEA `configure`
script and makefiles; MSVC builds use its native `win/makefile.vc`. The
submodule remains unmodified. A patch applied to the staged build copy makes
TEA use `TK_XLIBSW` from the selected Tk instead of independently discovering
system X11. Both the TEA macro and the distributed `configure` script are
patched, so Autoconf is not needed to build the release. The build also
backports upstream commit `52f2a4e` to fix shell commands in the makefile rule
that generates the build identifier from a source checkout.

A staged patch removes the absolute runtime directory from Tktable’s embedded
initialization script. The script still searches Tcl package paths and can use
its embedded runtime; this keeps binary path cleanup from truncating the script.

Build and run the upstream Tcl tests against the installed extension with:

```sh
cmake --build /path/to/bext-build --target TKTABLE_check
```

With `BEXT_XMIN_ROOT` set, this target starts a private Xmin server. Otherwise
it uses the current display. The runner returns failure when any upstream test
fails. BRL-CAD's `tclcad_test_multi_interp_gui` additionally checks the Archer
wrapper, including row selection across a 100,000-row grid, Unicode clipboard
paste, and rejected edits.
