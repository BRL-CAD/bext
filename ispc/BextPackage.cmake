bext_package(ispc OUTPUT install GROUPS OSPRAY)

bext_sbom_component("ispc/ispc"
  UPSTREAM_URL "https://github.com/ispc/ispc"
  VERSION "1.30.0"
  PURL "pkg:github/ispc/ispc@v1.30.0"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "LICENSE.txt"
  LICENSE_SHA256 "617beba3c8821b13db6c0038c3188b4001bba560e94b003751deb0bb16465385"
)
