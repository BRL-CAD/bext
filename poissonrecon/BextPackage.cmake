bext_package(poissonrecon OUTPUT noinstall GROUPS BRLCAD)

bext_sbom_component("poissonrecon/PoissonRecon"
  UPSTREAM_URL "https://github.com/mkazhdan/PoissonRecon"
  PURL_BASE "pkg:github/mkazhdan/PoissonRecon"
)

bext_sbom_component("poissonrecon/PoissonRecon"
  LICENSE "MIT"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "10c758ad12e91b19915b8401ad687403d151d97de0d4b6c4aa2d54bcba95db27"
)
