bext_package(mmesh OUTPUT install GROUPS BRLCAD)

bext_sbom_component("mmesh/mmesh"
  UPSTREAM_URL "https://github.com/BRL-CAD/mmesh"
  PURL_BASE "pkg:github/BRL-CAD/mmesh"
)

bext_sbom_component("mmesh/mmesh"
  LICENSE "LicenseRef-MMesh-Aggregate"
  LICENSE_NAME "MMesh aggregate license"
  LICENSE_FILE "@/mmesh/licenses/mmesh.txt"
  LICENSE_SHA256 "20c933c458ee1e055fb5539ca267d3f173ac166f3a96f39fc9bf188aff4e492d"
  LICENSE_SOURCE_FILE "./LICENSE"
  LICENSE_SOURCE_SHA256 "20c933c458ee1e055fb5539ca267d3f173ac166f3a96f39fc9bf188aff4e492d"
  REVIEWED_REVISION "ffdca572a318a914022539fd20eaee661312962d"
  LICENSE_COMMENT "The majority is zlib-like, while cchash.h has a separate informal grant."
  PURPOSE "LIBRARY"
)
