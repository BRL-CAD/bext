bext_package(strclear OUTPUT noinstall)

bext_sbom_component("strclear/strclear"
  UPSTREAM_URL "https://github.com/BRL-CAD/strclear"
  PURL_BASE "pkg:github/BRL-CAD/strclear"
  LICENSE "BSD-3-Clause AND MIT"
  LICENSE_FILE "@/strclear/licenses/strclear.txt"
  LICENSE_SHA256 "68bdd8fb52cb6cd20cb48969a37f7c915dc2a8ca40bf07701cc546d5bb7aefdc"
  LICENSE_SOURCE_FILE "LICENSE.txt"
  LICENSE_SOURCE_SHA256 "68bdd8fb52cb6cd20cb48969a37f7c915dc2a8ca40bf07701cc546d5bb7aefdc"
  REVIEWED_REVISION "954852b92306ff210431cf471efb007782e2144e"
  PURPOSE "APPLICATION"
  SCOPE "BUILD"
)
