bext_package(yaml-cpp OUTPUT install GROUPS APPLESEED)

bext_sbom_component("yaml-cpp/yaml-cpp"
  UPSTREAM_URL "https://github.com/jbeder/yaml-cpp"
  VERSION "0.8.0"
  PURL "pkg:github/jbeder/yaml-cpp@0.8.0"
  LICENSE "MIT"
  LICENSE_FILE "./LICENSE"
  LICENSE_SHA256 "aa6fcc27be034e41e21dd832f9175bfe694a48491d9e14ff0fa278e19ad14f1b"
)
