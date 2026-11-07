bext_package(minizip-ng OUTPUT install GROUPS APPLESEED)

bext_sbom_component("minizip-ng/minizip-ng" UPSTREAM_URL "https://github.com/zlib-ng/minizip-ng")

bext_sbom_component("minizip-ng/minizip-ng"
  VERSION "4.0.7"
  PURL "pkg:github/zlib-ng/minizip-ng@4.0.7"
)

bext_sbom_component("minizip-ng/minizip-ng"
  LICENSE "Zlib"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "675181c03fc1302a1c8554c00f7be9bb420c5dbc9dcc2013433cec144413de03"
)
