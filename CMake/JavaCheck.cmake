#                 J A V A C H E C K . C M A K E
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
# Utility function to check that dlls can be loaded by the Java
# System.loadLibrary mechanism. Parameters (all are mandatory):
#
# JCEXEC = path to javac compiler
# JAREXEC = path to jar archive creater
# JEXEC = path to java executable
# DLLSUFFIX = platform specific shared library suffix (.so, .dll, etc.)
# DLL_DIR = directory holding shared library files to check

function(JavaCheck JC_EXEC JAR_EXEC J_EXEC DLL_SUFFIX dlldir)

  if (NOT EXISTS "${dlldir}")
    message(FATAL_ERROR "Dll directory ${dlldir} not found\n")
  endif ()
  if (NOT EXISTS "${JC_EXEC}")
    message(FATAL_ERROR "Java compiler executable ${JC_EXEC} not found\n")
  endif ()
  if (NOT EXISTS "${JAR_EXEC}")
    message(FATAL_ERROR "Java archive creation executable ${JAR_EXEC} not found\n")
  endif ()
  if (NOT EXISTS "${J_EXEC}")
    message(FATAL_ERROR "Java executable ${J_EXEC} not found\n")
  endif ()

  file(WRITE ${dlldir}/LoadLib.java "class LoadLib
{
        public static void main(String []args)
        {
                if (args.length < 1) {
                        System.out.println(\"No DLL specified\");
                        System.exit(1);
                }
                System.out.println(\"Loading \" + args[0]);
                System.loadLibrary(args[0]);
                System.out.println(\"Done\");
        }
}
"
  )

  # Help make sure Java finds the dynamically linked libraries in question
  if (WIN32)
    set(ENV{PATH} "${dlldir};$ENV{PATH}")
  else (WIN32)
    set(ENV{LD_LIBRARY_PATH} "${dlldir}")
  endif (WIN32)

  # Compile the file and create the jar archive
  execute_process(COMMAND ${JC_EXEC} LoadLib.java
    RESULT_VARIABLE LSTATUS OUTPUT_VARIABLE LOUT ERROR_VARIABLE LOUT
    WORKING_DIRECTORY ${dlldir}
    )
  if (LSTATUS)
    file(REMOVE ${dlldir}/LoadLib.java)
    message(FATAL_ERROR "Failed to compile LoadLib.class: ${LOUT}")
  endif (LSTATUS)
  execute_process(COMMAND ${JAR_EXEC} -cf LoadLib.jar LoadLib.class
    RESULT_VARIABLE LSTATUS OUTPUT_VARIABLE LOUT ERROR_VARIABLE LOUT
    WORKING_DIRECTORY ${dlldir}
    )
  if (LSTATUS)
    file(REMOVE ${dlldir}/LoadLib.java)
    file(REMOVE ${dlldir}/LoadLib.class)
    message(FATAL_ERROR "Failed to create JAR file LoadLib.jar: ${LOUT}")
  endif (LSTATUS)

  file(GLOB dll_files RELATIVE "${dlldir}" "${dlldir}/*${DLL_SUFFIX}")
  set(load_fail 0)
  foreach(dlf ${dll_files})
    string(REGEX REPLACE "^lib" "" dlf "${dlf}")
    string(REGEX REPLACE "${DLL_SUFFIX}$" "" dlf "${dlf}")
    message("Dll LoadLibrary check: ${J_EXEC} -cp LoadLib.jar LoadLib ${dlf}")
    execute_process(COMMAND ${J_EXEC} -cp LoadLib.jar LoadLib ${dlf}
      RESULT_VARIABLE LSTATUS OUTPUT_VARIABLE LOUT ERROR_VARIABLE LOUT
      WORKING_DIRECTORY ${dlldir}
      )
    if (LSTATUS)
      message("LoadLibrary call with dll file ${dlf} did not succeed: ${LOUT}")
      set(load_fail 1)
    endif (LSTATUS)
  endforeach(dlf ${dll_files})
  file(REMOVE ${dlldir}/LoadLib.java)
  file(REMOVE ${dlldir}/LoadLib.class)
  file(REMOVE ${dlldir}/LoadLib.jar)
  if (load_fail)
    message(FATAL_ERROR "Dll files present that failed to load with LoadLibrary.")
  endif (load_fail)
endfunction(JavaCheck)

if (JCEXEC AND JAREXEC AND JEXEC AND DLLSUFFIX AND DLL_DIR)
  JavaCheck(${JCEXEC} ${JAREXEC} ${JEXEC} ${DLLSUFFIX} ${DLL_DIR})
endif ()

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
