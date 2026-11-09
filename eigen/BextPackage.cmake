bext_package(eigen OUTPUT noinstall GROUPS BRLCAD APPLESEED)

bext_sbom_component("eigen/eigen"
  UPSTREAM_URL "https://gitlab.com/libeigen/eigen.git"
  VERSION "5.0.1"
  PURL "pkg:git/gitlab.com/libeigen/eigen.git@5.0.1"
  LICENSE "MPL-2.0 AND BSD-3-Clause"
  LICENSE_FILES "COPYING.MPL2" "COPYING.BSD"
  LICENSE_SHA256S
    "66a3107d5ad6a058aab753eaac2047ccb2ed0e39465dd0fe5844da3e300d5172"
    "51928dce36213c5333ba3172e847d735d4c6e9b7ff2722a326c49067155b82eb"
  LICENSE_COMMENT "The MINPACK-derived code is represented as a contained package."
  PURPOSE "LIBRARY"
  SCOPE "BUILD"
)

bext_sbom_subcomponent("eigen/eigen" "unsupported/Eigen/src/NonLinearOptimization"
  NAME "Eigen MINPACK-derived code"
  UPSTREAM_URL "https://netlib.org/minpack/"
  PURL_BASE "pkg:git/gitlab.com/libeigen/eigen.git"
  PURL_SUBPATH "unsupported/Eigen/src/NonLinearOptimization"
  LICENSE "LicenseRef-Eigen-Minpack"
  LICENSE_NAME "Eigen MINPACK notice"
  LICENSE_FILE "@/eigen/licenses/eigen-minpack.txt"
  LICENSE_SHA256 "c87b7f8ee88f6195e91743820c00354833583aef091b72e2d4a49c8e28e798a0"
  LICENSE_SOURCE_FILE "COPYING.MINPACK"
  LICENSE_SOURCE_SHA256 "c87b7f8ee88f6195e91743820c00354833583aef091b72e2d4a49c8e28e798a0"
  REVIEWED_REVISION "bc3b39870ecb690a623a3f49149a358b95c5781d"
  PURPOSE "LIBRARY"
  SCOPE "BUILD"
)
