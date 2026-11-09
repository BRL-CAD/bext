bext_package(ncurses OUTPUT install GROUPS OSPRAY)

bext_sbom_component("ncurses/ncurses"
  UPSTREAM_URL "https://invisible-island.net/ncurses/"
  PURL_BASE "pkg:github/BRL-CAD/ncurses"
  LICENSE "X11-distribute-modifications-variant"
  LICENSE_FILE "COPYING"
  LICENSE_SHA256 "87a4c4442337b8968ef956031c406b74f9cb7149b7ba87311bdaba534816201c"
  PURPOSE "LIBRARY"
)
