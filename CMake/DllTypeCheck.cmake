#               D L L T Y P E C H E C K . C M A K E
# BRL-CAD
#
# Copyright (c) 2024 United States Government as represented by
# the U.S. Army Research Laboratory.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following
# disclaimer in the documentation and/or other materials provided
# with the distribution.
#
# 3. The name of the author may not be used to endorse or promote
# products derived from this software without specific prior written
# permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
###
# Utility function to check the type of dlls built by bext.

include(CMakeParseArguments)

function(DllTypeCheck btype dlldir)
  if (NOT EXISTS "${dlldir}")
    return()
  endif (NOT EXISTS "${dlldir}")
  find_program(DUMPBIN_EXEC dumpbin)
  if (NOT DUMPBIN_EXEC)
    return()
  endif (NOT DUMPBIN_EXEC)
  file(GLOB dll_files RELATIVE "${dlldir}" "${dlldir}/*.dll")
  set(non_match 0)
  foreach(dlf ${dll_files})
    # dumpbin doesn't like CMake style paths
    file(TO_NATIVE_PATH "${dlf}" TBFN)
    # https://stackoverflow.com/a/28304716/2037687
    execute_process(COMMAND ${DUMPBIN_EXEC} /dependents ${TBFN}
      OUTPUT_VARIABLE DB_OUT
      ERROR_VARIABLE DB_OUT)
    if ("${btype}" STREQUAL "Release")
      if ("${DB_OUT}" MATCHES ".*MSVCP[0-9]*d.dll.*" OR "${DB_OUT}" MATCHES ".*MSVCP[0-9]*D.dll.*")
	set(non_match 1)
        message("Release build specified, but ${dlf} is built as Debug.")
      endif ("${DB_OUT}" MATCHES ".*MSVCP[0-9]*d.dll.*" OR "${DB_OUT}" MATCHES ".*MSVCP[0-9]*D.dll.*")
    endif ("${btype}" STREQUAL "Release")
    if ("${btype}" STREQUAL "Debug")
      if (NOT "${DB_OUT}" MATCHES ".*MSVCP[0-9]*d.dll.*" AND NOT "${DB_OUT}" MATCHES ".*MSVCP[0-9]*D.dll.*")
	set(non_match 1)
        message("Debug build specified, but ${dlf} is built as Release.")
      endif (NOT "${DB_OUT}" MATCHES ".*MSVCP[0-9]*d.dll.*" AND NOT "${DB_OUT}" MATCHES ".*MSVCP[0-9]*D.dll.*")
    endif ("${btype}" STREQUAL "Debug")
  endforeach(dlf ${dll_files})
  if (non_match)
    message(FATAL_ERROR "Found non-matching dll files - check build logic.")
  endif (non_match)
endfunction(DllTypeCheck btype)

if (CMAKE_BUILD_TYPE AND DLL_DIR)
  DllTypeCheck(${CMAKE_BUILD_TYPE} ${DLL_DIR})
endif (CMAKE_BUILD_TYPE AND DLL_DIR)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
