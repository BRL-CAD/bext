bext_package(llvm OUTPUT install GROUPS APPLESEED OSPRAY
  LEGAL_NAMES
    LLVM
)

bext_sbom_component("llvm/llvm-project"
  UPSTREAM_URL "https://github.com/llvm/llvm-project"
  PURL_BASE "pkg:github/llvm/llvm-project"
)

bext_sbom_component("llvm/llvm-project"
  LICENSE "LicenseRef-LLVM-Project-Aggregate"
  LICENSE_NAME "LLVM Project aggregate license and third-party notices"
  LICENSE_FILE "@/llvm/licenses/llvm.txt"
  LICENSE_SHA256 "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee"
  LICENSE_SOURCE_FILE "llvm/LICENSE.TXT"
  LICENSE_SOURCE_SHA256 "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee"
  REVIEWED_REVISION "1daf978f2715ae657b852861d13760e9a5936f4c"
  LICENSE_COMMENT "LLVM is primarily Apache-2.0 WITH LLVM-exception, with legacy NCSA and bundled third-party terms retained in this aggregate notice."
  PURPOSE "LIBRARY"
)
