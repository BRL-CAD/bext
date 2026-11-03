# Included by each CMake dependency's project() call.  Establish an actual
# global pool so upstreams which append their own pools retain this one.
if (CMAKE_GENERATOR MATCHES "Ninja")
  get_property(bext_pools GLOBAL PROPERTY JOB_POOLS)
  if (NOT bext_pools)
    set(bext_pools ${CMAKE_JOB_POOLS})
  endif ()
  list(FILTER bext_pools EXCLUDE REGEX "^bext_(compile|link)=")
  list(APPEND bext_pools "bext_compile=${BEXT_BUILD_JOBS}" "bext_link=${BEXT_LINK_JOBS}")
  set_property(GLOBAL PROPERTY JOB_POOLS "${bext_pools}")
  set(CMAKE_JOB_POOL_COMPILE bext_compile)
  set(CMAKE_JOB_POOL_LINK bext_link)
endif ()
