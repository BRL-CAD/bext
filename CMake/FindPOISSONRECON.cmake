# Find Adaptive Multigrid Solver headers for Poisson Surface Reconstruction
#
# Once done this will define
#
#  POISSONRECON_FOUND - system has Adaptive Multigrid Solver headers
#  POISSONRECON_INCLUDE_DIR - the Adaptive Multigrid Solver include directory
#
# and the following imported target:
#
#  POISSONRECON::POISSONRECON- Provides include dir for headers

set(_POISSONRECON_SEARCHES)

# Search POISSONRECON_ROOT first if it is set.
if(POISSONRECON_ROOT)
  set(_POISSONRECON_SEARCH_ROOT PATHS ${POISSONRECON_ROOT} NO_DEFAULT_PATH)
  list(APPEND _POISSONRECON_SEARCHES _POISSONRECON_SEARCH_ROOT)
endif()

# Try each search configuration.
foreach(search ${_POISSONRECON_SEARCHES})
	find_path(POISSONRECON_INCLUDE_DIR NAMES SPSR/Reconstructors.h ${${search}} PATH_SUFFIXES include)
endforeach()

mark_as_advanced(POISSONRECON_INCLUDE_DIR)

# handle the QUIETLY and REQUIRED arguments and set ZLIB_FOUND to TRUE if
# all listed variables are TRUE
include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(POISSONRECON REQUIRED_VARS POISSONRECON_INCLUDE_DIR)

if(POISSONRECON_FOUND)
    set(POISSONRECON_INCLUDE_DIRS ${POISSONRECON_INCLUDE_DIR})

    if(NOT TARGET POISSONRECON::POISSONRECON)
      add_library(POISSONRECON::POISSONRECON UNKNOWN IMPORTED)
      set_target_properties(POISSONRECON::POISSONRECON PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${POISSONRECON_INCLUDE_DIRS}")
    endif()
endif()
