# xmltools provides the xsltproc and xmllint tools for Docbook processing
bext_enable_all_default(XMLTOOLS xmltools)

# bext: xmltools bundles libxml2 + libxslt, which have deep Windows portability
# gaps that manifest differently on each compiler:
# - mingw-gcc: libxml2's globals.h uses TLS-accessor macros (xmlGenericError
#   becomes a function call via __xmlGenericError()) when LIBXML_THREAD_ENABLED
#   is set for the libxml build, but libxslt sees the plain variable name --
#   link fails with "undefined reference to __imp_xmlGenericError".
# - clang-cl (clang / icc branches): libxslt tentative-definition duplicate
#   symbols under lld-link (fixed via -fcommon), plus -Wimplicit-function-
#   declaration on libxml2's xmlIO.c (fixed via -Wno-...).
# xmltools produces xsltproc/xmllint for Docbook -> HTML/PDF documentation
# generation, which is not required for building brlcad or IBRT.  Skip the
# submodule build on WIN32 non-MSVC entirely; brlcad will only miss the
# Docbook doc-generation targets, which we don't invoke in our workflow.
# MSVC/Linux/macOS continue building xmltools as before (ENABLE_XMLTOOLS
# retains its upstream auto-detect logic; this override fires only when the
# user hasn't explicitly asked for the build).
if (WIN32 AND NOT MSVC AND NOT DEFINED ENABLE_XMLTOOLS)
  set(ENABLE_XMLTOOLS OFF CACHE BOOL "Enable xmltools build" FORCE)
  message(STATUS "bext: xmltools disabled on WIN32 non-MSVC (libxml2/libxslt "
                 "Windows portability; xsltproc/xmllint used only for Docbook)")
endif ()

if (NOT ENABLE_XMLTOOLS)

  find_program(XSLTPROC_EXECUTABLE xsltproc)
  mark_as_advanced(XSLTPROC_EXECUTABLE)

  find_program(XMLLINT_EXECUTABLE xmllint)
  mark_as_advanced(XMLLINT_EXECUTABLE)

  if (NOT XSLTPROC_EXECUTABLE OR NOT XMLLINT_EXECUTABLE)
    if (NOT DEFINED ENABLE_XMLTOOLS)
      set(ENABLE_XMLTOOLS "ON" CACHE BOOL "Enable xmltools build")
    endif (NOT DEFINED ENABLE_XMLTOOLS)
  endif (NOT XSLTPROC_EXECUTABLE OR NOT XMLLINT_EXECUTABLE)

endif (NOT ENABLE_XMLTOOLS)
set(ENABLE_XMLTOOLS "${ENABLE_XMLTOOLS}" CACHE BOOL "Enable xmltools build")

if (ENABLE_XMLTOOLS)

  git_submodule_init(xmltools CMakeLists.txt)

  RegisterDeps(XMLTOOLS)

  # bext: xmltools bundles libxml2 + libxslt.  Compatibility gaps vs MSVC cl.exe:
  # (1) libxml2 src/xmlIO.c and libxslt call read/write/close/getcwd/isatty
  #     without including <unistd.h> / <io.h>.  MSVC's cl.exe accepts these
  #     implicit function declarations; Clang 20+ / clang-cl / GCC 15+ promote
  #     -Wimplicit-function-declaration to an error per C99.  Silence via
  #     -Wno-implicit-function-declaration.
  # (2) libxml2 headers declare globals like xmlGenericError via XMLPUBVAR
  #     without `extern`, relying on tentative definition COMDAT behavior.
  #     GCC 10+ defaults to -fno-common; libxslt then fails to link with
  #     "undefined reference to __imp_xmlGenericError" because the dllimport
  #     side and the definition side disagree on symbol decoration.  Clang's
  #     lld-link ALSO errors "duplicate symbol: xsltMaxVars".  MSVC cl.exe /
  #     link.exe deduplicate silently.  Restore legacy behavior via -fcommon.
  # Gate on any GNU-style driver (Clang or GNU); leave MSVC cl.exe untouched.
  # Compose an ADDITIVE flag string via CMAKE_C_FLAGS_INIT rather than
  # -DCMAKE_C_FLAGS=... so the sub-configure keeps CMake's default C flags
  # instead of clobbering them to empty.
  set(XMLTOOLS_BEXT_C_FLAGS_INIT "")
  if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    if (MSVC)
      set(XMLTOOLS_BEXT_C_FLAGS_INIT "/clang:-Wno-implicit-function-declaration /clang:-fcommon")
    else ()
      set(XMLTOOLS_BEXT_C_FLAGS_INIT "-Wno-implicit-function-declaration -fcommon")
    endif ()
  elseif (CMAKE_C_COMPILER_ID STREQUAL "GNU")
    set(XMLTOOLS_BEXT_C_FLAGS_INIT "-Wno-implicit-function-declaration -fcommon")
  endif ()

  ExternalProject_Add(XMLTOOLS_BLD
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/xmltools"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DCMAKE_C_FLAGS_INIT=${XMLTOOLS_BEXT_C_FLAGS_INIT}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_NOBUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_NOBUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(XMLTOOLS XMLTOOLS_DEPENDS)

endif (ENABLE_XMLTOOLS)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
