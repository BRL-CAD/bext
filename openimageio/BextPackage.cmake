bext_package(openimageio OUTPUT install GROUPS APPLESEED)

bext_sbom_component("openimageio/oiio" UPSTREAM_URL "https://github.com/AcademySoftwareFoundation/OpenImageIO")

bext_sbom_component("openimageio/oiio" NAME "OpenImageIO")

bext_sbom_component("openimageio/oiio"
  VERSION "2.5.12.0"
  PURL "pkg:github/AcademySoftwareFoundation/OpenImageIO@v2.5.12.0"
  CPE "cpe:2.3:a:openimageio:openimageio:2.5.12.0:*:*:*:*:*:*:*"
  CPE_STATUS "NVD_PRODUCT"
  CPE_PRODUCT_EVIDENCE "cpe:2.3:a:openimageio:openimageio:2.4.4.2:*:*:*:*:*:*:*"
  LICENSE "LicenseRef-OIIO-Aggregate"
  LICENSE_NAME "OpenImageIO source-tree aggregate license notice"
  LICENSE_FILE "THIRD-PARTY.md"
  LICENSE_SHA256 "cc196651d3bce30df3327abb9e494a95faa234f7eb577a80bf6af566a997c590"
  LICENSE_COMMENT "Includes OpenImageIO's Apache-2.0 terms and the terms for incorporated third-party code. Externally linked dependencies remain separate packages."
  PURPOSE "LIBRARY"
)

bext_sbom_subcomponent("openimageio/oiio" "src/include/OpenImageIO/detail/farmhash.h"
  NAME "FarmHash"
  UPSTREAM_URL "https://github.com/google/farmhash"
  PURL_BASE "pkg:github/AcademySoftwareFoundation/OpenImageIO"
  PURL_SUBPATH "src/include/OpenImageIO/detail/farmhash.h"
  LICENSE "MIT"
  LICENSE_FILE "THIRD-PARTY.md"
  LICENSE_SHA256 "cc196651d3bce30df3327abb9e494a95faa234f7eb577a80bf6af566a997c590"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)

bext_sbom_subcomponent("openimageio/oiio" "src/libutil/xxhash.cpp"
  NAME "xxHash"
  UPSTREAM_URL "https://github.com/Cyan4973/xxHash"
  PURL_BASE "pkg:github/AcademySoftwareFoundation/OpenImageIO"
  PURL_SUBPATH "src/libutil/xxhash.cpp"
  LICENSE "BSD-2-Clause"
  LICENSE_FILE "THIRD-PARTY.md"
  LICENSE_SHA256 "cc196651d3bce30df3327abb9e494a95faa234f7eb577a80bf6af566a997c590"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)

bext_sbom_subcomponent("openimageio/oiio" "src/libOpenImageIO/kissfft.hh"
  NAME "KissFFT"
  UPSTREAM_URL "https://github.com/mborgerding/kissfft"
  PURL_BASE "pkg:github/AcademySoftwareFoundation/OpenImageIO"
  PURL_SUBPATH "src/libOpenImageIO/kissfft.hh"
  LICENSE "BSD-3-Clause"
  LICENSE_FILE "THIRD-PARTY.md"
  LICENSE_SHA256 "cc196651d3bce30df3327abb9e494a95faa234f7eb577a80bf6af566a997c590"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)

bext_sbom_subcomponent("openimageio/oiio" "src/libutil/thread.cpp"
  NAME "CTPL-derived thread pool"
  UPSTREAM_URL "https://github.com/vit-vit/CTPL"
  PURL_BASE "pkg:github/AcademySoftwareFoundation/OpenImageIO"
  PURL_SUBPATH "src/libutil/thread.cpp"
  LICENSE "Apache-2.0"
  LICENSE_FILE "THIRD-PARTY.md"
  LICENSE_SHA256 "cc196651d3bce30df3327abb9e494a95faa234f7eb577a80bf6af566a997c590"
  PURPOSE "LIBRARY"
  SCOPE "RUNTIME"
)
