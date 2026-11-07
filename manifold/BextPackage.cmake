bext_package(manifold OUTPUT install GROUPS BRLCAD)

bext_sbom_component("manifold/manifold" UPSTREAM_URL "https://github.com/elalish/manifold")

bext_sbom_component("manifold/manifold"
  VERSION "3.5.3"
  PURL "pkg:github/elalish/manifold@v3.5.3"
)

bext_sbom_component("manifold/manifold"
  LICENSE "Apache-2.0"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
)
