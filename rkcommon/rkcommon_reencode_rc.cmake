# bext: rkcommon ships rkcommon/rkcommon.rc encoded as UTF-16LE with BOM.  MSVC's
# rc.exe accepts UTF-16; GNU windres (used by MinGW-w64 and clang/mingw) does
# not -- it reads the file as bytes and emits "syntax error" on line 1 because
# every character is followed by a NUL.  The submodule's inner CMakeLists.txt
# adds rkcommon.rc unconditionally as a source, so we cannot skip it from the
# parent.  Fix: re-encode the file in place to UTF-8 before configure.
#
# Byte-exact -- do NOT use file(STRINGS ENCODING UTF-16LE).  The file contains
# a bare LF (0x0A) inside two quoted string literals (VALUE "FileDescription"
# and VALUE "LegalCopyright") in addition to CRLF line terminators.  Both
# rc.exe and windres tolerate a bare LF INSIDE a "..." literal, but if the
# splitter treats the bare LF as an end-of-line then the "..." runs off the
# end of the line and windres emits "missing terminating "" character".
# Rebuilding via file(READ ... HEX) drops the BOM and every other byte
# (rkcommon.rc is pure ASCII in the low byte of each UTF-16 code unit),
# preserving all embedded NULs-of-line-continuation intact.
#
# Idempotent: keyed on the BOM (fffe) so BUILD_ALWAYS re-runs skip after the
# first pass.  Invoked from parent bext/rkcommon/CMakeLists.txt PATCH_COMMAND
# as `cmake -DRC=<SOURCE_DIR>/rkcommon/rkcommon.rc -P <this>`.
if (NOT DEFINED RC)
  message(FATAL_ERROR "rkcommon_reencode_rc.cmake: RC variable not set")
endif ()
if (NOT EXISTS "${RC}")
  message(FATAL_ERROR "rkcommon_reencode_rc.cmake: ${RC} not found")
endif ()
file(READ "${RC}" HEAD_HEX LIMIT 2 HEX)
if (HEAD_HEX STREQUAL "fffe")
  file(READ "${RC}" ALL_HEX HEX)
  # Strip BOM (first 2 bytes = 4 hex chars).
  string(SUBSTRING "${ALL_HEX}" 4 -1 ALL_HEX)
  string(LENGTH "${ALL_HEX}" LEN)
  # Keep the low byte of every UTF-16 code unit (2 chars out of every 4).
  set(TEXT "")
  set(i 0)
  while (i LESS LEN)
    string(SUBSTRING "${ALL_HEX}" ${i} 2 BH)
    math(EXPR DEC "0x${BH}")
    # string(ASCII 0 ...) is illegal; skip stray NULs defensively (should not
    # happen -- rkcommon.rc's low-byte payload is pure printable + CR/LF).
    if (NOT DEC EQUAL 0)
      string(ASCII ${DEC} CH)
      string(APPEND TEXT "${CH}")
    endif ()
    math(EXPR i "${i} + 4")
  endwhile ()
  file(WRITE "${RC}" "${TEXT}")
  message(STATUS "rkcommon.rc re-encoded UTF-16LE -> UTF-8 for GNU windres (byte-exact)")
else ()
  message(STATUS "rkcommon.rc already non-UTF-16 (BOM=${HEAD_HEX}); skipping re-encode")
endif ()
