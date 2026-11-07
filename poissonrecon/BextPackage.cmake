bext_package(poissonrecon OUTPUT noinstall GROUPS BRLCAD)

bext_sbom_component("poissonrecon/PoissonRecon"
  VERSION "18.75"
  REVIEWED_REVISION "cd6dc7d33f028b2e6496f5cd999c25cecd56aff2"
  UPSTREAM_URL "https://github.com/mkazhdan/PoissonRecon"
  PURL_BASE "pkg:github/mkazhdan/PoissonRecon"
)

bext_sbom_component("poissonrecon/PoissonRecon"
  LICENSE "MIT"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "10c758ad12e91b19915b8401ad687403d151d97de0d4b6c4aa2d54bcba95db27"
)
