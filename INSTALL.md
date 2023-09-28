# bext - Installation

For building all of the projects present in this repository, you will need Git, CMake, a modern C/C++ compiler and some support libraries installed on your operating system.  If you want flex and bison you'll also need a working Autotools stack on non-Windows platforms.

# Ubuntu Linux

Basic tools needed for all configurations:
```
sudo apt install git cmake gcc g++
```

For Tk you'll need basic X11 libraries:
```
sudo apt install libfontconfig1-dev libfreetype6-dev xserver-xorg-dev libx11-dev libxi-dev libxext-dev
```

For Qt, Appleseed and OSPRay you'll need Python
```
sudo apt install libpython3-dev
```

For Qt you'll also need (in addition to the above) the XCB packages (see https://doc.qt.io/qt-6/linux-requirements.html)
```
sudo apt install libx11-xcb-dev libxfixes-dev libxrender-dev libxcb1-dev libxcb-cursor-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev
```

For OSPRay you'll need m4, and for the ISPC compiler used by OSPRay you'll need the gcc multilib packages:
```
sudo apt install m4 gcc-multilib g++-multilib
```

If you don't want to build flex and bison for the OSPRay/Appleseed stacks you can also install those:
```
sudo apt install flex bison
```

If you do want to build them, install the Autotools stack:
```
sudo apt-get install autotools-dev autoconf
```

# Windows

Windows will need some variety of Python installed for Qt/Appleseed/OSPRay.

# OSX

XCode

What else? - TODO

