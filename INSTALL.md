# bext - Installation Notes

This file covers machine setup and source checkout details.  For the main build
flow and option behavior, see [README.md](README.md).

# Base requirements

All builds need:

* Git
* CMake 3.19 or newer
* A modern C compiler
* A modern C++ compiler

Additional requirements depend on the enabled stacks:

* `USE_APPLESEED` and `USE_OSPRAY` will use a system `flex` and
  `bison` if they are already installed.  If they are not and `bext`
  needs to build them locally on non-Windows platforms, a working
  Autotools stack is also needed.
* `USE_QT`, `USE_APPLESEED`, or `USE_OSPRAY` need Python 3 available
  to the build.
* `USE_OSPRAY` needs `m4`.

# Source checkout options

Default clone:

```sh
git clone https://github.com/BRL-CAD/bext
```

This is usually the best starting point.  `bext` will populate submodules on
demand during configure.

Recursive clone:

```sh
git clone --recursive https://github.com/BRL-CAD/bext
```

Use this if you want all submodule content fetched up front, or if you expect
to configure and build without network access later.

Shallow clone options:

* `cmake ../bext -DGIT_SHALLOW_CLONE=ON ...`
* `git clone --recursive --depth=1 https://github.com/BRL-CAD/bext`

Shallow clones are fine for compile-only use, but they are not recommended for
development or for submodule update work.

# Path and directory caveats

* Avoid symlinked source or build directory paths.  `bext` warns about these
  because they can cause downstream install and rpath problems.
* On non-Windows platforms, bundled Tcl/Tk builds do not support spaces in the
  source or build directory path.

# Ubuntu Linux

Base packages:

```sh
sudo apt install git cmake gcc g++
```

For Tcl/Tk builds:

```sh
sudo apt install libfontconfig1-dev libfreetype6-dev xserver-xorg-dev libx11-dev libxi-dev libxext-dev
```

For Qt, Appleseed, and OSPRay:

```sh
sudo apt install libpython3-dev
```

For Qt on X11 systems, install the XCB development packages:

```sh
sudo apt install libx11-xcb-dev libxfixes-dev libxrender-dev libxcb1-dev libxcb-cursor-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev
```

For OSPRay:

```sh
sudo apt install m4 gcc-multilib g++-multilib
```

If you want to rely on system `flex` and `bison`:

```sh
sudo apt install flex bison
```

If `bext` may need to build `flex` and `bison` locally:

```sh
sudo apt install autotools-dev autoconf
```

# Windows

If you enable Qt, Appleseed, or OSPRay, make sure Python 3 is installed and
available in the build environment.

# macOS

Assuming XCode is installed, good to go.
