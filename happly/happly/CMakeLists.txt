# Upstream is header-only; this local adapter supplies an install target.
cmake_minimum_required(VERSION 3.26)
project(happly LANGUAGES CXX)
include(GNUInstallDirs)
install(FILES happly.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
