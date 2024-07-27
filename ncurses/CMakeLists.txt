# Unless we have ENABLE_ALL set, base the building of the tools on
# the system detection results
if (NOT WIN32)

  if (ENABLE_ALL AND NOT DEFINED ENABLE_NCURSES)
    set(ENABLE_NCURSES ON)
  endif (ENABLE_ALL AND NOT DEFINED ENABLE_NCURSES)

  if (NOT ENABLE_NCURSES)

    find_package(Curses)

    if (NOT Curses_FOUND AND NOT DEFINED ENABLE_NCURSES)
      set(ENABLE_NCURSES ON)
    endif (NOT Curses_FOUND AND NOT DEFINED ENABLE_NCURSES)

  endif (NOT ENABLE_NCURSES)

  set(ENABLE_NCURSES "${ENABLE_NCURSES}" CACHE BOOL "Enable ncurses build")

  if (ENABLE_NCURSES)

    git_submodule_init(ncurses README)

    TargetDeps(NCURSES)

    set(NCURSES_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/NCURSES_BLD-prefix/src/NCURSES_BLD")

    ExternalProject_Add(NCURSES_BLD
      URL "${CMAKE_CURRENT_SOURCE_DIR}/ncurses"
      BUILD_IN_SOURCE ON
      BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
      #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/ncurses.patch
      #CONFIGURE_COMMAND ${NCURSES_SRC_DIR}/autogen.sh
      CONFIGURE_COMMAND ${NCURSES_SRC_DIR}/configure --with-shared --enable-rpath --prefix=${CMAKE_BUNDLE_INSTALL_PREFIX}
      BUILD_COMMAND make -j${pcnt}
      INSTALL_COMMAND make -j1 install
      DEPENDS ${ZLIB_TARGET}
      LOG_CONFIGURE ${EXT_BUILD_QUIET}
      LOG_BUILD ${EXT_BUILD_QUIET}
      LOG_INSTALL ${EXT_BUILD_QUIET}
      LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
      STEP_TARGETS install
      )

    TargetInstallDeps(NCURSES NCURSES_DEPENDS)

    # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
    configure_file(
      ${CMAKE_CURRENT_SOURCE_DIR}/ncurses/COPYING
      ${DOC_LICENSE_DIR}/ncurses.txt
      COPYONLY
      )

  endif (ENABLE_NCURSES)

endif (NOT WIN32)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8


