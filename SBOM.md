# bext SBOM guide

`bext` produces source and build Software Bills of Materials (SBOMs) in both
SPDX 2.3 and CycloneDX 1.6 JSON. This guide covers the normal commands and
which output to use. Maintainer details, scanner setup, and VEX workflows are
in [MAINTAINING.md](MAINTAINING.md#sbom-formats-and-local-tools).

## Generate the source inventory

Configure a build tree, then build the `sbom` target:

```sh
cmake --preset auto
cmake --build build/auto/Release --target sbom --config Release
```

This writes the following files at the top of the build tree:

* `bext.spdx.json` - SPDX 2.3 JSON.
* `bext.cdx.json` - CycloneDX 1.6 JSON.

These files describe the dependencies declared by the committed `bext`
revision, including dependencies outside the configured build profile. They
are source inventories, not records of the packages or files installed by a
particular build. Generating them needs CMake and Git, but does not build the
dependency libraries or require Python.

The source tree must be clean because the document identifies the current
commit. For an intentional development snapshot, enable dirty-tree output when
configuring:

```sh
cmake --preset auto -DBEXT_SBOM_ALLOW_DIRTY=ON
cmake --build build/auto/Release --target sbom --config Release
```

The resulting document retains the committed metadata and records that the
working tree was dirty. Do not use a dirty-tree SBOM as a release artifact.

## Generate build inventories

A normal completed build finalizes the bundle and automatically generates
inventories for what that build produced:

```sh
cmake --build build/auto/Release --config Release --parallel 8
```

To rerun only finalization after the dependency install steps are complete:

```sh
cmake --build build/auto/Release --target bext_finalize --config Release
```

With the default preset layout, the relevant files are:

| Output | Scope |
| --- | --- |
| `build/auto/Release/bext.build.spdx.json` | Installed redistribution content in SPDX 2.3 JSON. |
| `build/auto/Release/bext.build.cdx.json` | The same installed content in CycloneDX 1.6 JSON. |
| `build/auto/Release/bext-package.build.spdx.json` | The reusable bext archive, including tracked `install/` and `noinstall/` content, in SPDX JSON. |
| `build/auto/Release/bext-package.build.cdx.json` | The same archive content in CycloneDX JSON. |

Use `bext.build.*` when inventorying the dependencies redistributed with a
downstream product such as BRL-CAD. Use `bext-package.build.*` when publishing
the complete reusable bext bundle, including its build tools. These build
inventories reflect the configured package selection and contain file-level
evidence; the source inventory does not.

If `BEXT_DISCARD_WORK=ON`, build the normal `bext_release` target rather than
invoking `bext_finalize` directly. It captures evidence before deleting the
temporary source and build directories.

## Choose a downstream package policy

Most BRL-CAD users should keep the defaults. A normal bext build places runtime
dependencies and development inputs in `install/` and build-only tools in
`noinstall/`, while its generated exclusion manifest tells BRL-CAD which
`install/` files belong in a downstream runtime package. BRL-CAD can therefore
use headers and build tools without redistributing them.

The package policy primarily affects downstream staging and the install-product
`bext.build.*` inventories. It does not change which dependency projects are
selected or narrow the repository-wide `bext.spdx.json` and `bext.cdx.json`
source inventories. A dependency may avoid producing optional tools that the
selected policy cannot retain. The `bext-package.build.*` inventories describe
the complete reusable archive actually produced by that configuration.

Configure policy choices with the build tree. For example, to prepare an SDK
rather than a runtime-only downstream package:

```sh
cmake --preset auto -DBEXT_PACKAGE_PROFILE=SDK
cmake --build build/auto/Release --config Release --parallel 8
```

The available controls are:

| CMake setting | Default | Purpose |
| --- | --- | --- |
| `BEXT_PACKAGE_PROFILE` | `RUNTIME` | Selects `RUNTIME`, `SDK`, or `COMPLETE` downstream content. |
| `BEXT_PACKAGE_LICENSE_POLICY` | `REDISTRIBUTABLE` | Excludes `LICENSE_RESTRICTED` groups. `UNRESTRICTED` retains them when the distributor has separately determined that is appropriate. |
| `BEXT_PACKAGE_FILTER_LARGE_UNUSED` | `ON` | Allows qualifying `LARGE_UNUSED` files to be excluded from the `RUNTIME` profile. |
| `BEXT_PACKAGE_LARGE_FILE_THRESHOLD_MB` | `25` | Sets the size threshold for `LARGE_UNUSED` exclusion and retained-large-file reporting. |
| `BEXT_SBOM_ALLOW_DIRTY` | `OFF` | Allows a non-release source SBOM from a dirty checkout; it does not alter downstream package content. |

`BEXT_PACKAGE_PROFILE` expresses the intended audience:

* `RUNTIME` is the normal BRL-CAD redistribution profile. It omits development
  files, build tools, auxiliary tools, tests, and qualifying large unused
  assets.
* `SDK` is for consumers that must compile against the packaged dependencies.
  It retains development files and build tools, but still omits auxiliary
  tools and tests.
* `COMPLETE` is for a complete toolkit or archival package. It retains all
  profile-controlled categories. License policy remains independent.

The license setting is deliberately separate from the profile. Selecting
`COMPLETE` does not override the default `REDISTRIBUTABLE` policy, and selecting
`UNRESTRICTED` does not grant additional license rights or establish that a
particular distribution is compliant.

### Package categories

Bext wrappers classify related files into policy categories. The profile and
license settings resolve those categories as follows:

| Category | `RUNTIME` | `SDK` | `COMPLETE` | Meaning |
| --- | --- | --- | --- | --- |
| `ALWAYS` | Excluded | Excluded | Excluded | Content that must never enter downstream staging. |
| `LICENSE_RESTRICTED` | License policy | License policy | License policy | Content retained only with `BEXT_PACKAGE_LICENSE_POLICY=UNRESTRICTED`. |
| `DEVELOPMENT` | Excluded | Retained | Retained | Headers, static/import libraries, CMake/pkg-config files, and similar development metadata. |
| `BUILD_TOOL` | Excluded | Retained | Retained | Programs needed to compile or generate downstream content. |
| `AUXILIARY_TOOL` | Excluded | Excluded | Retained | Optional command-line utilities not needed by the runtime or SDK build workflow. |
| `TEST` | Excluded | Excluded | Retained | Test programs and test-only data. |
| `LARGE_UNUSED` | Conditional | Retained | Retained | Runtime-unneeded assets excluded only when filtering is enabled and the file meets the configured size threshold. |

Files may belong to multiple categories; any applicable exclusion wins. Files
not assigned to an exclusion category remain available for downstream staging.
Finalization records every decision in `bext-install-exclude-manifest.json` and
reports retained files at or above the large-file threshold for review.

## Validate the output

The `sbom` target always runs bext's built-in SPDX checks. If `pyspdxtools` was
on `PATH` when CMake configured the build tree, it also runs that validator.

Build the native semantic validator to check package identity, licenses,
relationships, provenance, evidence, and parity between the two formats:

```sh
cmake --build build/auto/Release --target sbom_validate --config Release
```

For independent SPDX and CycloneDX schema validation, create a local Python
environment and invoke the adapter directly:

```sh
python3 -m venv build/sbom-tools/venv
build/sbom-tools/venv/bin/python -m pip install -r CMake/sbom-requirements.txt
build/sbom-tools/venv/bin/python CMake/ValidateSbom.py \
  --spdx build/auto/Release/bext.spdx.json \
  --cyclonedx build/auto/Release/bext.cdx.json
```

On Windows, use `py -3 -m venv build/sbom-tools/venv` and
`build/sbom-tools/venv/Scripts/python.exe` in the last two commands.

## Review metadata and scanner inputs

These optional targets do not build the dependency libraries:

```sh
cmake --build build/auto/Release --target sbom_metadata_report --config Release
cmake --build build/auto/Release --target sbom_scan_inputs --config Release
```

`sbom_metadata_report` writes `sbom-metadata-gaps.md` for incremental metadata
review. `sbom_scan_inputs` writes `bext.conan.spdx.json` and
`bext.conan.cdx.json`, plus coverage reports, as advisory-scanner projections.
Use the original SBOMs as the release records; projections deliberately adapt
package identities for scanner compatibility.

For vulnerability scanning, OpenVEX, external tool installation, and release
review policy, continue with
[MAINTAINING.md](MAINTAINING.md#setting-up-the-external-supply-chain-tools).
