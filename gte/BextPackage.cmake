bext_package(gte OUTPUT noinstall GROUPS BRLCAD)

bext_sbom_component("gte/GeometricTools" UPSTREAM_URL "https://github.com/davideberly/GeometricTools")

bext_sbom_component("gte/GeometricTools" NAME "GeometricTools")

bext_sbom_component("gte/GeometricTools"
  VERSION "8.2"
  PURL "pkg:github/davideberly/GeometricTools@GTE-version-8.2"
)

bext_sbom_component("gte/GeometricTools"
  LICENSE "BSL-1.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566"
)
