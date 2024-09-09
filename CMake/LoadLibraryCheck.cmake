#           L O A D L I B R A R Y C H E C K . C M A K E
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
# Utility function to check that a dll can be loaded by the LoadLibrary
# function on Windows.

function(LoadLibraryCheck LLTEST_EXEC dlldir)
  if (NOT EXISTS "${dlldir}")
    return()
  endif (NOT EXISTS "${dlldir}")
  if (NOT EXISTS "${LLTEST_EXEC}")
    return()
  endif (NOT EXISTS "${LLTEST_EXEC}")
  file(GLOB dll_files RELATIVE "${dlldir}" "${dlldir}/*.dll")
  set(load_fail 0)
  foreach(dlf ${dll_files})
    message("Dll LoadLibrary check: ${dlf}")
    execute_process(COMMAND ${LLTEST_EXEC} ${dlf} RESULT_VARIABLE LSTATUS OUTPUT_VARIABLE LOUT)
    if (LSTATUS)
      message("LoadLibrary call with dll file ${dllfile} did not succeed.")
      set(load_fail 1)
    endif (LSTATUS)
  endforeach(dlf ${dll_files})
  if (load_fail)
    message(FATAL_ERROR "Dll files present that failed to load with LoadLibrary.")
  endif (load_fail)
endfunction(LoadLibraryCheck)

if (CMAKE_BUILD_TYPE AND LEXEC AND DLL_DIR)
  LoadLibraryCheck(${CMAKE_BUILD_TYPE} ${LEXEC} ${DLL_DIR})
endif (CMAKE_BUILD_TYPE AND LEXEC AND DLL_DIR)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
