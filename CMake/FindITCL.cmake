# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

#[=======================================================================[.rst:
FindITCL
--------

This module finds if Itcl is installed and determines where the include
files and libraries are.  It also determines what the name of the
library is.  This code sets the following variables:

::

ITCL_FOUND              = Itcl was found
ITCL_LIBRARY            = path to Itcl library (tcl tcl80)
ITCL_INCLUDE_PATH       = path to where itcl.h can be found
ITCL_STUB_LIBRARY       = path to Itcl stub library

#]=======================================================================]


set(_ITCL_SEARCHES)

# Search ITCL_ROOT first if it is set.
if(ITCL_ROOT)
  set(_ITCL_SEARCH_ROOT PATHS ${ITCL_ROOT} NO_DEFAULT_PATH)
  list(APPEND _ITCL_SEARCHES _ITCL_SEARCH_ROOT)
endif()

set(ITCL_POSSIBLE_LIB_PATH_SUFFIXES
  lib
  lib/itcl
  lib/itcl3.4
  itcl
  itcl3.4
  )

set(ITCL_POSSIBLE_LIB_NAMES
  itcl
  itcl3
  itcl3.4
  )

if(NOT ITCL_LIBRARY)
  foreach(search ${_ITCL_SEARCHES})
    find_library(ITCL_LIBRARY
      NAMES ${ITCL_POSSIBLE_LIB_NAMES}
      NAMES_PER_DIR ${${search}}
      PATH_SUFFIXES ${ITCL_POSSIBLE_LIB_PATH_SUFFIXES})
  endforeach()
endif()
if(NOT ITCL_LIBRARY)
  find_library(ITCL_LIBRARY
    NAMES ${ITCL_POSSIBLE_LIB_NAMES}
    PATH_SUFFIXES ${ITCL_POSSIBLE_LIB_PATH_SUFFIXES}
    )
endif(NOT ITCL_LIBRARY)

set(ITCLSTUB_POSSIBLE_LIB_NAMES
  itclstub
  itclstub3
  itclstub3.4
  )
if(NOT ITCL_STUB_LIBRARY)
  foreach(search ${_ITCL_SEARCHES})
    find_library(ITCL_STUB_LIBRARY
      NAMES ${ITCLSTUB_POSSIBLE_LIB_NAMES}
      NAMES_PER_DIR ${${search}}
      PATH_SUFFIXES ${ITCL_POSSIBLE_LIB_PATH_SUFFIXES}
      )
  endforeach()
endif()
if(NOT ITCL_STUB_LIBRARY)
  find_library(ITCL_STUB_LIBRARY
    NAMES ${ITCLSTUB_POSSIBLE_LIB_NAMES}
    PATH_SUFFIXES ${ITCL_POSSIBLE_LIB_PATH_SUFFIXES}
    )
endif()

set(ITCL_POSSIBLE_INCLUDE_PATH_SUFFIXES
  include
  include/itcl
  include/itcl3
  include/itcl3.4
  )

foreach(search ${_ITCL_SEARCHES})
  find_path(ITCL_INCLUDE_PATH
    NAMES itcl.h ${${search}}
    PATH_SUFFIXES ${ITCL_POSSIBLE_INCLUDE_PATH_SUFFIXES}
    )
endforeach()
if (NOT ITCL_INCLUDE_PATH)
  find_path(ITCL_INCLUDE_PATH
    NAMES itcl.h
    HINTS ${ITCL_POSSIBLE_INCLUDE_PATHS}
    )
endif()

include(FindPackageHandleStandardArgs)

FIND_PACKAGE_HANDLE_STANDARD_ARGS(ITCL
  REQUIRED_VARS ITCL_LIBRARY ITCL_STUB_LIBRARY ITCL_INCLUDE_PATH
  )

mark_as_advanced(
  ITCL_INCLUDE_PATH
  ITCL_LIBRARY
  ITCL_STUB_LIBRARY
  )

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
