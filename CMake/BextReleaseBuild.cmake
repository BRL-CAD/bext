include_guard(GLOBAL)
include(ExternalProject)

option(BEXT_DISCARD_WORK "Discard successful dependency working trees during sequential builds" OFF)
if (BEXT_DISCARD_WORK)
  # A discarded compilation directory cannot support BUILD_ALWAYS.
  set(EXT_BUILD_ALWAYS OFF)
endif ()
set(BEXT_LINK_JOBS 1 CACHE STRING "Concurrent links per CMake dependency")
if (NOT BEXT_LINK_JOBS MATCHES "^[1-9][0-9]*$")
  message(FATAL_ERROR "BEXT_LINK_JOBS must be a positive integer")
endif ()
if (NOT BEXT_DISCARD_WORK AND EXISTS "${CMAKE_BINARY_DIR}/bext-release-state.json")
  message(FATAL_ERROR "This build used BEXT_DISCARD_WORK. Use a fresh build directory to disable it.")
endif ()
if (BEXT_DISCARD_WORK AND CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
  message(FATAL_ERROR "BEXT_DISCARD_WORK requires an out-of-source build")
endif ()

#---------------------------------------------------------------------
# CMake 4.0 removed support for cmake_minimum_required(VERSION < 3.5), but a
# number of our bundled third party projects still declare such old minimums.
# Because each dependency is configured as an independent ExternalProject
# sub-build (a separate cmake invocation), a top level CMAKE_POLICY_VERSION_MINIMUM
# setting - whether on the command line or from a CMakePresets cache variable -
# does NOT reach those sub-builds.  To make old dependencies configure regardless
# of how bext itself is invoked, establish a default policy floor here and wrap
# ExternalProject_Add so that every CMake-based sub-build is configured with it.
#
# The flag is inserted as the first CMAKE_ARGS value so it always lands inside
# the CMAKE_ARGS group regardless of which ExternalProject keywords follow.
# Sub-builds that drive a non-CMake configure (i.e. have no CMAKE_ARGS) are left
# untouched.  Defining a command that already exists makes the original available
# under the same name with a leading underscore, a documented CMake behavior.
if (NOT DEFINED CMAKE_POLICY_VERSION_MINIMUM)
  set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
endif (NOT DEFINED CMAKE_POLICY_VERSION_MINIMUM)

function(ExternalProject_Add name)
  # Rebuild the call as a string of bracket-quoted arguments so that empty
  # arguments (e.g. CONFIGURE_COMMAND "") and values containing spaces,
  # semicolons or generator expressions are all preserved exactly.  Inject the
  # policy floor immediately after the CMAKE_ARGS token so it becomes the first
  # CMAKE_ARGS value.
  set(ep_call "_ExternalProject_Add([==[${name}]==]")
  set(has_cmake_args FALSE)
  set(has_build_command FALSE)
  set(has_install_command FALSE)
  if (ARGC GREATER 1)
    math(EXPR ep_last "${ARGC} - 1")
    foreach(ep_i RANGE 1 ${ep_last})
      if (BEXT_DISCARD_WORK AND ep_i GREATER 1)
        math(EXPR previous "${ep_i} - 1")
        if ("${ARGV${previous}}" STREQUAL "BUILD_ALWAYS")
          string(APPEND ep_call " OFF")
          continue()
        endif ()
      endif ()
      string(APPEND ep_call " [==[${ARGV${ep_i}}]==]")
      if ("${ARGV${ep_i}}" STREQUAL "BUILD_COMMAND")
        set(has_build_command TRUE)
      elseif ("${ARGV${ep_i}}" STREQUAL "INSTALL_COMMAND")
        set(has_install_command TRUE)
      endif ()
      if ("${ARGV${ep_i}}" STREQUAL "CMAKE_ARGS")
        set(has_cmake_args TRUE)
        string(APPEND ep_call " [==[-DCMAKE_POLICY_VERSION_MINIMUM=${CMAKE_POLICY_VERSION_MINIMUM}]==]")
        string(APPEND ep_call " [==[-DBEXT_BUILD_JOBS=${BEXT_BUILD_JOBS}]==]")
        string(APPEND ep_call " [==[-DBEXT_LINK_JOBS=${BEXT_LINK_JOBS}]==]")
        string(APPEND ep_call " [==[-DCMAKE_PROJECT_INCLUDE=${CMAKE_CURRENT_FUNCTION_LIST_DIR}/BextBuildResources.cmake]==]")
      endif ("${ARGV${ep_i}}" STREQUAL "CMAKE_ARGS")
    endforeach(ep_i RANGE 1 ${ep_last})
  endif (ARGC GREATER 1)
  if (has_cmake_args)
    foreach(step BUILD INSTALL)
      string(TOLOWER "${step}" lower_step)
      if (NOT has_${lower_step}_command)
        # These builds set their own parallelism and may use a different make
        # implementation than the parent, whose jobserver flags are incompatible.
        string(APPEND ep_call " ${step}_COMMAND [==[${CMAKE_COMMAND}]==] -E env --unset=MAKEFLAGS --unset=MFLAGS [==[${CMAKE_COMMAND}]==] --build <BINARY_DIR> --parallel ${BEXT_BUILD_JOBS}")
        if (CMAKE_CONFIGURATION_TYPES)
          string(APPEND ep_call " --config [==[$<CONFIG>]==]")
        endif ()
        if (step STREQUAL "INSTALL")
          string(APPEND ep_call " --target install")
        endif ()
      endif ()
    endforeach()
  endif ()
  # Ninja's built-in console pool is global to the superbuild and has depth
  # one.  All expensive phases share it, even for an unbounded outer ninja.
  # Dependency Ninja processes receive their own compile/link limits below.
  string(APPEND ep_call " USES_TERMINAL_CONFIGURE TRUE USES_TERMINAL_BUILD TRUE USES_TERMINAL_INSTALL TRUE")
  if (BEXT_DISCARD_WORK)
    string(APPEND ep_call " EXCLUDE_FROM_ALL TRUE")
  endif ()
  string(APPEND ep_call ")")
  cmake_language(EVAL CODE "${ep_call}")
  if(COMMAND bext_register_vex)
    bext_register_vex("${name}")
  endif()
  set_property(GLOBAL APPEND PROPERTY BEXT_EXTERNAL_PROJECTS "${name}")
  if (TARGET ${name}-install)
    get_property(_bext_install_targets GLOBAL PROPERTY BEXT_INSTALL_TARGETS)
    list(APPEND _bext_install_targets ${name}-install)
    list(REMOVE_DUPLICATES _bext_install_targets)
    set_property(GLOBAL PROPERTY BEXT_INSTALL_TARGETS "${_bext_install_targets}")
  endif (TARGET ${name}-install)
endfunction(ExternalProject_Add name)

function(_bext_json_quote output value)
  string(REPLACE "\\" "\\\\" value "${value}")
  string(REPLACE "\"" "\\\"" value "${value}")
  string(REPLACE "\n" "\\n" value "${value}")
  string(REPLACE "\r" "\\r" value "${value}")
  string(REPLACE "\t" "\\t" value "${value}")
  set(${output} "\"${value}\"" PARENT_SCOPE)
endfunction()

# Generate the plan after all install dependencies and the finalizer exist.
function(bext_configure_release_build)
  if (NOT BEXT_DISCARD_WORK)
    return()
  endif ()
  find_package(Python3 3.8 REQUIRED COMPONENTS Interpreter)
  set(plan "{}")
  foreach(field build_root source_root prefix jobs)
    if (field STREQUAL "build_root")
      set(value "${CMAKE_BINARY_DIR}")
    elseif (field STREQUAL "source_root")
      set(value "${CMAKE_SOURCE_DIR}")
    elseif (field STREQUAL "prefix")
      set(value "${CMAKE_INSTALL_PREFIX}")
    else ()
      set(value "${BEXT_BUILD_JOBS}")
    endif ()
    _bext_json_quote(quoted "${value}")
    string(JSON plan SET "${plan}" "${field}" "${quoted}")
  endforeach()
  _bext_json_quote(quoted "$<CONFIG>")
  string(JSON plan SET "${plan}" config "${quoted}")
  _bext_json_quote(quoted "${CMAKE_COMMAND}")
  string(JSON plan SET "${plan}" cmake "${quoted}")
  string(JSON plan SET "${plan}" install_roots "[]")
  _bext_json_quote(quoted "${CMAKE_BUNDLE_INSTALL_PREFIX}")
  string(JSON plan SET "${plan}" install_roots 0 "${quoted}")
  _bext_json_quote(quoted "${CMAKE_NOBUNDLE_INSTALL_PREFIX}")
  string(JSON plan SET "${plan}" install_roots 1 "${quoted}")
  string(JSON plan SET "${plan}" projects "[]")
  get_property(projects GLOBAL PROPERTY BEXT_EXTERNAL_PROJECTS)
  get_property(unmatched_selector_ids GLOBAL PROPERTY BEXT_SBOM_SELECTOR_IDS)
  set(index 0)
  foreach(project IN LISTS projects)
    if (NOT TARGET ${project}-install)
      message(FATAL_ERROR "${project} needs an install step target for BEXT_DISCARD_WORK")
    endif ()
    set(record "{}")
    _bext_json_quote(quoted "${project}")
    string(JSON record SET "${record}" name "${quoted}")
    # Excluded wrapper directories may not appear in the root Visual Studio
    # solution. Give the driver a root-level project with an explicit target
    # dependency so MSBuild can reach the wrapper's generated project file.
    # These forwarding targets are not part of the default build.
    set(build_target "bext_release_${project}")
    add_custom_target(${build_target})
    add_dependencies(${build_target} ${project})
    _bext_json_quote(quoted "${build_target}")
    string(JSON record SET "${record}" build_target "${quoted}")
    foreach(field SOURCE_DIR BINARY_DIR STAMP_DIR TMP_DIR LOG_DIR)
      ExternalProject_Get_Property(${project} ${field})
      _bext_json_quote(quoted "${${field}}")
      string(TOLOWER "${field}" key)
      string(JSON record SET "${record}" "${key}" "${quoted}")
    endforeach()
    get_property(upstream TARGET ${project} PROPERTY _EP_URL)
    if (NOT upstream)
      set(upstream "${SOURCE_DIR}")
    endif ()
    _bext_json_quote(quoted "${upstream}")
    string(JSON record SET "${record}" upstream "${quoted}")
    get_target_property(wrapper_binary_dir ${project} BINARY_DIR)
    _bext_json_quote(quoted
      "${wrapper_binary_dir}/CMakeFiles/bext-install-manifests/${project}/install_manifest.txt")
    string(JSON record SET "${record}" preserved_install_manifest "${quoted}")
    string(JSON record SET "${record}" selector_caches "[]")
    set(selector_cache_index 0)
    foreach(selector_id IN LISTS unmatched_selector_ids)
      get_property(selector_target GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_TARGET")
      if (NOT selector_target STREQUAL project)
        continue()
      endif ()
      set(cache_record "{}")
      foreach(field CACHE PRESERVED_CACHE)
        get_property(value GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_${field}")
        _bext_json_quote(quoted "${value}")
        string(TOLOWER "${field}" key)
        string(JSON cache_record SET "${cache_record}" "${key}" "${quoted}")
      endforeach()
      string(JSON record SET "${record}" selector_caches
        ${selector_cache_index} "${cache_record}")
      math(EXPR selector_cache_index "${selector_cache_index} + 1")
      list(REMOVE_ITEM unmatched_selector_ids "${selector_id}")
    endforeach()
    set(deferred false)
    get_target_property(retain_work ${project} BEXT_RETAIN_WORK_UNTIL_FINALIZE)
    if(retain_work)
      set(deferred true)
    endif ()
    string(JSON record SET "${record}" deferred "${deferred}")
    string(JSON plan SET "${plan}" projects ${index} "${record}")
    math(EXPR index "${index} + 1")
  endforeach()
  if (unmatched_selector_ids)
    list(GET unmatched_selector_ids 0 selector_id)
    get_property(component GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_COMPONENT")
    get_property(selector_target GLOBAL PROPERTY "BEXT_SBOM_SELECTOR_${selector_id}_TARGET")
    message(FATAL_ERROR
      "Installed SBOM selector for ${component} names unknown ExternalProject target: ${selector_target}")
  endif ()
  # These are wrapper inputs, not the populated third-party source trees.
  file(GLOB inputs
    "${CMAKE_SOURCE_DIR}/CMakeLists.txt" "${CMAKE_SOURCE_DIR}/.gitmodules"
    "${CMAKE_SOURCE_DIR}/CMake/*.cmake" "${CMAKE_SOURCE_DIR}/CMake/*.py"
    "${CMAKE_SOURCE_DIR}/CMake/*.json"
    "${CMAKE_SOURCE_DIR}/*/CMakeLists.txt" "${CMAKE_SOURCE_DIR}/*/*.cmake"
    "${CMAKE_SOURCE_DIR}/*/*.in" "${CMAKE_SOURCE_DIR}/*/*.patch"
    "${CMAKE_SOURCE_DIR}/*/*.deps" "${CMAKE_SOURCE_DIR}/*/*.json")
  string(JSON plan SET "${plan}" inputs "[]")
  set(index 0)
  foreach(input IN LISTS inputs)
    _bext_json_quote(quoted "${input}")
    string(JSON plan SET "${plan}" inputs ${index} "${quoted}")
    math(EXPR index "${index} + 1")
  endforeach()
  set(plan_file "${CMAKE_BINARY_DIR}/bext-release-$<CONFIG>.json")
  file(GENERATE OUTPUT "${plan_file}" CONTENT "${plan}\n")
  add_custom_target(bext_release ALL
    COMMAND "${CMAKE_COMMAND}" "-DPLAN=${plan_file}" "-DPYTHON=${Python3_EXECUTABLE}"
      "-DDRIVER=${CMAKE_CURRENT_FUNCTION_LIST_DIR}/release_build.py"
      -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/BextRunReleaseBuild.cmake"
    USES_TERMINAL VERBATIM)
  set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES
    "${CMAKE_BINARY_DIR}/bext-release-state.json")
endfunction()
