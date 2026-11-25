bext_package(llvm OUTPUT install GROUPS APPLESEED OSPRAY
  LEGAL_NAMES
    LLVM
)

bext_sbom_component("llvm/llvm-project"
  VERSION "23.1.5"
  UPSTREAM_URL "https://github.com/llvm/llvm-project"
  PURL_BASE "pkg:github/llvm/llvm-project"
  LICENSE "LicenseRef-LLVM-Project-Aggregate"
  LICENSE_NAME "LLVM Project aggregate license and third-party notices"
  LICENSE_FILE "@/llvm/licenses/llvm.txt"
  LICENSE_SHA256 "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee"
  LICENSE_SOURCE_FILE "llvm/LICENSE.TXT"
  LICENSE_SOURCE_SHA256 "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee"
  REVIEWED_REVISION "392dfff97d29b59d77e5cac6d4b6ef2585fe7117"
  LICENSE_COMMENT "LLVM is primarily Apache-2.0 WITH LLVM-exception, with legacy NCSA and bundled third-party terms retained in this aggregate notice."
  PURPOSE "LIBRARY"
)
