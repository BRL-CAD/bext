bext_package(clipper2 OUTPUT install GROUPS BRLCAD)

bext_sbom_component("clipper2/Clipper2"
  UPSTREAM_URL "https://github.com/AngusJohnson/Clipper2"
  VERSION "1.5.4"
  PURL "pkg:github/AngusJohnson/Clipper2@Clipper2_1.5.4"
  LICENSE "BSL-1.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566"
)
