# Find GeometricTools Mathematics headers
#
# Once done this will define
#
#  GTE_FOUND - system has GTE Mathematics headers
#  GTE_INCLUDE_DIR - the GTE include directory
#
# and the following imported target:
#
#  GTE::GTE- Provides include dir for GeometricTools Mathematics headers

set(_GTE_SEARCHES)

# Search GTE_ROOT first if it is set.
if(GTE_ROOT)
  set(_GTE_SEARCH_ROOT PATHS ${GTE_ROOT} NO_DEFAULT_PATH)
  list(APPEND _GTE_SEARCHES _GTE_SEARCH_ROOT)
endif()

# Try each search configuration.
foreach(search ${_GTE_SEARCHES})
	find_path(GTE_INCLUDE_DIR NAMES GTE/Mathematics/ConvexHull3.h ${${search}} PATH_SUFFIXES include)
endforeach()

mark_as_advanced(GTE_INCLUDE_DIR)

# handle the QUIETLY and REQUIRED arguments and set ZLIB_FOUND to TRUE if
# all listed variables are TRUE
include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(GTE REQUIRED_VARS GTE_INCLUDE_DIR)

if(GTE_FOUND)
    set(GTE_INCLUDE_DIRS ${GTE_INCLUDE_DIR})

    if(NOT TARGET GTE::GTE)
      add_library(GTE::GTE UNKNOWN IMPORTED)
      set_target_properties(GTE::GTE PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${GTE_INCLUDE_DIRS}")
    endif()
endif()
