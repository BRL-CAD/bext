# bext dependency maintenance and integration guide

This guide covers maintaining dependency sources, writing wrappers, and
validating changes. For building and consuming bext, start with [README.md](README.md).
Use [INSTALL.md](INSTALL.md) for prerequisites, checkout choices, and repository
mappings, and [DEPENDENCIES.md](DEPENDENCIES.md) for the generated package map.

* [Scope and principles](#scope-and-principles)
* [Checkout and inspection](#checkout-and-inspection)
* [Dependency lifecycle](#dependency-lifecycle)
* [Writing a wrapper](#writing-a-wrapper)
* [Updating a dependency](#updating-a-dependency)
* [Bundle contract](#bundle-contract)
* [Validation and CI](#validation-and-ci)
* [Troubleshooting and reference](#troubleshooting-and-reference)
* [Example: pugixml from local snapshot to submodule](#example-pugixml-from-local-snapshot-to-submodule)

Shell examples assume the bext repository root unless another directory is
specified. Substitute real paths and selected revisions for placeholders.
Use an ordinary incremental build for development; reserve
`BEXT_DISCARD_WORK=ON` for builds whose sources and configuration are settled.

## Scope and principles

* Prefer a particular **upstream release tag**, when available. Verify the
  commit behind that tag and record that exact commit in bext's gitlink.
  Apply integration changes as bext patches against the released source.
  A branch name or a moving tag such as `latest` does not identify a release.
* BRL-CAD-hosted repositories preserve access to the chosen upstream source.
  Preserve and verify the candidate there **before changing bext's pin**,
  including a local pin change. Matching upstream commit IDs do not establish
  that the BRL-CAD repository can supply the source if upstream disappears.
  Mirroring an upstream tag does not require modifying its source or creating
  a `RELEASE` branch. Never move an upstream release tag to a patched commit.
* Project-owned tools such as `strclear` and `plief` may need a tested project
  commit rather than a third-party release. Their pins still change deliberately.
* Netpbm is an exception to the unmodified release-tag goal: bext currently
  consumes a maintained source copy with its own CMake build. Lemon is a
  maintained extraction of SQLite's generator sources, and regex is a
  historical BRL-CAD source import. Treat these as maintained-source exceptions,
  recording their source/version and local changes when updating them.
  This is not an exhaustive list. For any other exception, explain why a tag
  is unsuitable or unavailable and pin a tested commit. Missing tags in a
  local, possibly shallow checkout do not prove upstream has no release tags.
* Preserve repositories and commits referenced by historical bext versions.
  Removing a dependency from current bext is supported; deleting its hosted
  repository or rewriting away referenced commits can break old checkouts.
* Keep exploratory integrations on a development branch. Local snapshots let
  build logic be evaluated before a submodule is added. Do not commit the
  snapshot's source files into bext.
* Keep populated source checkouts intact. Stage a build-tree copy before
  applying patches or other source modifications. Install bundled outputs and
  legal notices in the designated locations, then test downstream use.
* Keep facts in their authoritative inputs: project groups/order in the root
  `CMakeLists.txt`, edges in wrapper `.deps` files, source URLs in `.gitmodules`,
  and commits in gitlinks. Generate the dependency table rather than editing it.

### Preparing the source repository

Choose an upstream release and review its source, optional features, and
included third-party components. Preserve the selected commit and tag in the
BRL-CAD fork or mirror before updating bext to refer to them. Publish
only the intended refs; a bulk `git push --tags` can publish unrelated tags.
Keep inherited fork automation disabled unless it is deliberately maintained.

The required order is:

1. Fetch the selected upstream release into a separate source-maintenance
   checkout and record the tag's resolved commit.
2. Publish that tag and its required objects to the BRL-CAD repository. For
   maintained-source exceptions, publish a persistent ref containing the
   prepared commit. Preserve any required nested dependency sources too.
3. Verify availability with a fresh clone from the BRL-CAD repository, using
   no local object references, alternate object stores, or URL rewrites back
   to upstream. Check out the recorded commit and confirm its identity. Verify
   required nested sources through their intended repositories or mirrors.
   Merely listing a remote tag or finding the commit in an existing local
   checkout is insufficient evidence of independent source availability.
4. Only then update bext's source checkout and gitlink, refresh its integration,
   and run candidate validation. Do not defer mirroring until bext is ready to
   commit or publish: upstream could disappear during that interval.

For a release tag, after checking that `upstream` identifies the original
project and `origin` identifies the BRL-CAD repository, the source-maintenance
and independent verification commands are:

```sh
git -C <maintenance-clone> fetch upstream tag <release-tag>
git -C <maintenance-clone> rev-parse '<release-tag>^{commit}'
git -C <maintenance-clone> push origin refs/tags/<release-tag>:refs/tags/<release-tag>
git clone --no-local --no-checkout <brlcad-repository-url> <fresh-verification-directory>
git -C <fresh-verification-directory> checkout --detach <verified-commit>
git -C <fresh-verification-directory> rev-parse HEAD
```

For a tag-based candidate, the checked-out commit must match the recorded
upstream release commit. For a maintained-source exception, verify the prepared
BRL-CAD commit instead and retain its upstream version/import provenance. A
failed verification blocks the bext pin update; use the preserved source to
complete or repair the BRL-CAD copy first.

Use bext patches for build-system adaptations, symbol/library naming, install
layout, and compatibility fixes. Prefer upstream fixes when practical. If an
unmodified release cannot be used, document the necessary source preparation
and retain its relationship to upstream. A `RELEASE` branch can support such
an exception, but it is not the default source-selection mechanism.

Nested dependencies must also be reproducible and available from the chosen
repositories or mirrors. Keep their pins and notices under review. Some older
forks replace nested submodules with committed copies; updating those forks
requires updating those copies too. Do not apply that transformation to every
new release by default. Explain any necessary source exclusions or vendoring
and check the resulting dependency and license requirements.

## Checkout and inspection

### Reproduce a bext revision

Before switching revisions, preserve local work in bext and its submodules.
Because `.gitmodules` commonly specifies `ignore = dirty`, a clean parent
status alone does not establish that dependency sources are clean:

```sh
git status --short --ignore-submodules=none
git submodule foreach --recursive 'git status --short'
```

For an existing checkout, select the desired bext revision and align populated
submodules with its recorded pins:

```sh
git switch --detach <bext-revision>
git submodule update --checkout --recursive
```

The parent checkout and submodule checkout are separate operations. Ordinary
submodule updates use the parent's recorded pins; `--remote` instead selects
remote-tracking branch tips and is not a reproduction command. Detached HEAD
in a dependency is normal. Do not use `--force` to resolve unexpected changes.

For newly needed sources, use the profile bootstrap described in INSTALL.md;
`LIST_ONLY=ON` previews its selection. Direct Git commands use normal Git
configuration and do not inherit bext's CMake repository mappings. Explicit
`git submodule update --init --recursive -- <path>` is appropriate when normal
Git transport is intended. CMake does not automatically reset an already
populated dependency to its recorded pin, so verify it after switching bext.

### Inspect the three source states

| Question | Command for the pugixml example |
| --- | --- |
| What does the current bext commit pin? | `git ls-tree HEAD -- pugixml/pugixml` |
| What will the next commit pin? | `git ls-files --stage -- pugixml/pugixml` |
| What is actually checked out? | `git -C pugixml/pugixml rev-parse HEAD` |
| What source changes are staged? | `git diff --cached --submodule=log` |
| What local source edits exist? | `git -C pugixml/pugixml status --short` |

Submodule URLs can also differ between `.gitmodules`, local Git configuration,
and bext's process-scoped mappings. Use INSTALL.md's mapping preview and clone
reports to check transport without changing the canonical URLs.

## Dependency lifecycle

### Evaluate

Identify the consuming BRL-CAD feature and the relevant `USE_*` groups. Put
experimental work on a branch and start with a released source snapshot where
possible. Use `bext_local_source(PKG path url full-commit-id)` to record its
provenance without requiring a submodule or downloading anything. Confirm
which optional features, prerequisites, and notices are needed.

### Adopt

Once the targeted build and intended consumers work, complete and independently
verify the BRL-CAD source mirror as described above. Then replace the snapshot
with a submodule at the tested commit and replace local-source selection with
ordinary wrapper selection. Add
`ignore = dirty` to the new `.gitmodules` entry, consistent with existing
entries, while retaining explicit dirty-source checks during maintenance.
A `branch = RELEASE` entry is not required for a tag-based pin.

Stage the wrapper, its `BextPackage.cmake` descriptor, patches, dependency
edges, top-level registration,
`.gitmodules`, and gitlink. Generate and check the staged metadata as described
below before committing the integration. After committing, generate the
committed SBOM and repeat the committed metadata check. The required source
must already be available from BRL-CAD before this integration changes its pin.

### Maintain and retire

Use the controlled update procedure below. When retiring a dependency, remove
its consumers, wrapper registration, edges, resources, and submodule tracking
as one reviewed change, and regenerate the package table. Preserve historical
source availability. After preserving local work, use Git's normal removal:

```sh
git rm -- <dependency>/<source>
```

`git rm` stages the gitlink and `.gitmodules` removal. `git submodule deinit`
unregisters a local checkout; it does not retire the integration from history.
Manually deleting `.git/modules/...` is optional local storage cleanup, not a
required retirement step. Retaining it supports historical checkouts. See
[Git's submodule reference](https://git-scm.com/docs/gitsubmodules#_forms).

## Writing a wrapper

### Selection and dependencies

`USE_*` controls whether a wrapper is considered. Register BRL-CAD dependencies
under `BRLCAD`, including optional dependencies; add other consumer groups when
appropriate. Individual enables do not activate an inactive group.

Within an active group, `ENABLE_<pkg>=OFF` always prevents a local build,
including with `ENABLE_ALL=ON` or a matching `BRLCAD_COMPONENTS` selection.
`DISABLE_<pkg>=ON` also prevents a local build. Component exclusions and missing
experimental source can prevent a build even when `ENABLE_<pkg>=ON`. A local
build exclusion does not supply or validate a missing system package; coupled
stacks may reject an incompatible system/bundled combination.

Use the package's actual option spelling. Most use uppercase names; some
legacy custom wrappers, such as SQLite3, use mixed case. Pass the expanded
BRL-CAD component list, not only the directly requested components. Component
exclusions are per-configure decisions and must not become cached user OFF
preferences. Custom wrappers must preserve the same override precedence.

| Helper | Contract |
| --- | --- |
| `add_project(name GROUPS "...")` | Register a wrapper after its prerequisites and within all relevant consumer groups. |
| `cad_enable(PKG "component;...")` | Apply BRL-CAD component selection while preserving explicit local-build exclusions. Call before package selection. |
| `bext_enable(Package)` | Probe a system package and choose a local fallback when allowed. Match the actual find-module or config-package name. |
| `bext_local_source(PKG path url revision)` | Build a permitted, present CMake snapshot; skip an absent one. Cache the preference separately from availability. Does not track source or patch changes. |
| `git_submodule_init(path checkfile [PATCH_FILES ...] [INPUT_FILES ...] [PATCH_COMMAND_VAR var])` | Populate an adopted source when its checkfile is absent, using bext's Git mappings. Track its revision, ordered patch list, and other staging inputs; reset the wrapper build directory when that state changes. Only `PATCH_FILES` are passed to the patch tool. Call inside the enabled block. |
| `bext_patch_command(var patch-file...)` | Assemble ordered patch commands using the shared patch tool and options. Does not register change tracking or reset staged sources. |
| `RegisterDeps(PKG)` | Read `<wrapper>.deps`, require prerequisites to have been considered earlier, and expose `*_TARGET` flags. |
| `TargetInstallDeps(PKG PKG_DEPENDS)` | Make the external project's configure step wait for locally built prerequisite install steps. |

A `.deps` file lists provider names, one per line. Use the actual prerequisite
provider, not an installed library filename. List `PATCH` when following the
standard patch-tool convention. Place prerequisites earlier in the top-level
build; the metadata cycle check is not a substitute for configure-time ordering.

Normal selection usually starts with `cad_enable` followed by `bext_enable`.
During snapshot evaluation, use `cad_enable` if needed followed by
`bext_local_source`; do not then run ordinary fallback selection. When adopting
it, remove the local-source declaration and add the submodule initializer
inside the enabled block.

Bootstrap and metadata tools inspect declarations without evaluating wrappers.
Declare package groups, output role, providers, and SBOM assertions in the
wrapper's `BextPackage.cmake`; keep its groups consistent with `add_project`.
See DEPENDENCIES.md's SBOM contract for identity, license evidence, contained
packages, and installed-file ownership requirements.
When the installed package set depends on completed upstream configuration,
keep that selection logic in `<dependency>/SbomSelection.cmake` and register it
from the dependency wrapper with `bext_sbom_selector`. Set `TARGET` to the
owning ExternalProject; discard builds snapshot its registered configure cache
after installation and before removing the project's working tree.
Keep shared package compatibility settings in `<dependency>/BuildSettings.cmake`.
The root build discovers these before configuring wrappers so coupled stacks
can inspect one another's requirements. Keep package-specific SBOM checks in
`<dependency>/tests/Sbom.cmake`, defining `bext_test_<dependency>_sbom(sbom)`;
`CMake/TestSbom.cmake` discovers and calls them using the shared assertions.
Synthetic format and vulnerability fixtures remain with the generic tool tests.

Wrappers register post-install fixup targets with the global
`BEXT_INSTALL_FIXUP_TARGETS` property. Set an ExternalProject's
`BEXT_RETAIN_WORK_UNTIL_FINALIZE` target property when downstream builds still
need its staged implementation tree. The release driver does not maintain a
list of special package names. Dependency-local `PrepareInstall.cmake` hooks
run before final inventory collection; `FinalizeInstall.cmake` hooks run after
binary processing. Hooks run only for active components, with the finalizer's
install-root variables available, and must preserve the bundle contract.

Keep top-level `add_project` calls and source declarations on individual lines
with literal names, paths, URLs, and full commit IDs. Remove obsolete initializer
calls rather than leaving them commented: current metadata readers may still
recognize commented source calls. Follow an existing custom wrapper for
non-CMake sources; the snapshot helper currently checks for `CMakeLists.txt`.

### Source staging, patches, and configuration

* Use `SOURCE_DIR` for an existing source built in place when no patching or
  source staging is needed. Use a local `URL` to stage a copy before patching.
  Never switch to an in-place checkout just to simplify a path spelling.
* Keep adaptations against an upstream release in focused, ordered patch files.
  State the reason and upstream status where useful. Exercise a clean copy and
  repeated builds; regenerated staged sources must receive the same patches.
* Use the shared patch-command builder described below. It preserves
  `PATCH_EXECUTABLE` and `PATCH_OPTIONS`, including the wrapper's applicability
  checks and reject artifacts, without assuming a platform patch executable
  or GNU-only flags.
* Pass the selected compilers, build configuration, install prefix, and library
  directory. CMake ExternalProject builds receive the common policy floor and
  resource settings through the shared wrapper. Preserve generator expressions
  for configuration-dependent values.
* Point consumers at locally installed prerequisites when their `*_TARGET`
  flags are set. Test mixed system/bundled configurations, especially renamed
  zlib/PNG libraries. Find modules and config packages must honor the intended
  `*_ROOT` or package-directory hints and expose usable imported targets.
* Disable unwanted examples, tests, downloads, and optional features in the
  dependency build. Review requirements of enabled features and included
  source components; installing a license file alone does not establish
  license compatibility.
* Supply `STEP_TARGETS install` and register install dependencies. The discard
  driver requires an install step for every managed external project. Its
  root-level forwarding targets also make excluded wrappers reachable by
  native MSBuild; wrapper source project files are a separate build layer.

### Patch lists and rebuilds

For an adopted submodule, declare one ordered list of all patches that affect
its staged source. Pass that list to `git_submodule_init` before generating
files in the wrapper build directory or calling `ExternalProject_Add`:

```cmake
set(PKG_PATCH_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/pkg.patch"
  "${CMAKE_CURRENT_SOURCE_DIR}/pkg_install.patch")
git_submodule_init(source CMakeLists.txt
  PATCH_FILES ${PKG_PATCH_FILES}
  PATCH_COMMAND_VAR PKG_PATCH_COMMAND)

ExternalProject_Add(PKG_BLD
  URL "${CMAKE_CURRENT_SOURCE_DIR}/source"
  PATCH_COMMAND ${PKG_PATCH_COMMAND}
  # Other build and install arguments follow.
)
```

The initializer registers the patch files as CMake configure dependencies and
records their absolute paths and content hashes, in order, alongside the
source commit. On a later configure, a changed revision, patch list, or patch
content resets the wrapper's generated build directory so ExternalProject
stages a fresh source copy and reapplies the patches. Keep
`${PKG_PATCH_COMMAND}` unquoted when passing its command list to
`ExternalProject_Add`. `PATCH_COMMAND_VAR` requires a nonempty `PATCH_FILES`
list; omit both arguments for an unpatched dependency.
Uncommitted edits inside the source checkout do not change its recorded
commit; use a fresh build when testing those edits too.

For a custom patch driver, still register every input with `PATCH_FILES`,
including platform-specific and install-step patches, but omit
`PATCH_COMMAND_VAR` and supply the custom `PATCH_COMMAND`. Itk demonstrates
this pattern. Use `bext_patch_command` separately when the standard commands
must be combined with additional patch-step operations; use the same ordered
list for tracking and execution.

For an experimental, non-submodule snapshot, keep `bext_local_source` for
selection and provenance. Assemble its patch command with
`bext_patch_command` and patch a staged copy via `URL`, leaving the original
snapshot intact. Do not add `git_submodule_init` to obtain patch tracking:
that would declare a submodule to bootstrap and metadata tools before one
exists. `bext_local_source` has no `PATCH_FILES` or `PATCH_COMMAND_VAR`
handling, and `bext_patch_command` only assembles commands. After changing
snapshot contents, its recorded revision, or patches, recreate the dedicated
experimental build tree before retesting. Reconfiguring or using
`BUILD_ALWAYS` alone does not refresh an already patched source copy.

## Updating a dependency

Prerequisites: a clean or preserved working tree, the current pin, the proposed
release tag or exception commit already preserved and independently verified
in the BRL-CAD repository, and an incremental test build with enough space.
Complete [source preparation](#preparing-the-source-repository) first, before
changing the bext checkout or gitlink. Update one dependency or an explicitly
related set at a time.

For a release-tag update using normal Git transport:

```sh
git -C <dependency>/<source> fetch origin tag <release-tag>
git -C <dependency>/<source> rev-parse '<release-tag>^{commit}'
git -C <dependency>/<source> checkout --detach <verified-commit>
git -C <dependency>/<source> status --short
```

For a maintained-source exception, use the branch that holds the BRL-CAD
adaptation to identify a candidate during independent source verification.
Netpbm uses `brlcad`: verify a fresh clone from `BRL-CAD/netpbm`, resolve
`origin/brlcad`, and check out that exact commit there before changing bext.
Then fetch the branch into bext's submodule and select the verified commit:

```sh
git -C netpbm/netpbm fetch --no-tags origin brlcad
git -C netpbm/netpbm checkout --detach <verified-brlcad-commit>
git -C netpbm/netpbm status --short
```

Use the commit already verified, even if the branch advances during the update.
The exception branch and the upstream import can identify different commits;
select the maintained BRL-CAD subset rather than the full upstream import.
Review the subset diff against the previous bext pin and its upstream ancestry.
Check that its recorded provenance and generated build version agree with the
imported release. A new import may leave the retained library sources unchanged
while still correcting version information or provenance.

The origin above must be the BRL-CAD source already verified during preparation;
do not fetch from upstream inside bext as a substitute for completing the
mirror first. Do not repoint tags to hide integration patches. For
maintained-source exceptions, select the reviewed commit explicitly and record
the version/import changes.

Review changes since the old pin, refresh patches against the selected release,
check notices and optional dependencies, and build the wrapper and its
consumers. Use a fresh build after source, toolchain, or configuration changes
when prior outputs could mask a result. Changes to a submodule revision or
registered patch list/content reset its wrapper's generated build directory
at configure time; they do not prove an old install tree has been purged of
obsolete products. For non-submodule experiments, follow the fresh-build rule
under [patch lists and rebuilds](#patch-lists-and-rebuilds).

Stage only the intended gitlinks and integration changes, inspect the staged
submodule diff, and run INDEX validation. Commit the release tag/version,
resolved commit, reason for the update, relevant patch changes, and validation
results in the explanatory message. Record the prior source-availability
verification with the update's validation results.

To back out an unpublished experiment, restore the old source revision and
integration files while preserving local work. For a published update, use a
normal revert and realign populated submodules with the resulting pins. Rebuild
in a fresh output tree when removed or changed products could remain installed.

## Bundle contract

| Output | Purpose |
| --- | --- |
| `install/` | Libraries, headers, runtime assets, and notices intended for downstream bundling. |
| `noinstall/` | Build tools and compile-time-only assets; not automatically part of a downstream binary distribution. |
| `bext-install-manifest.json` | Finalized installed-file classifications and producer-prefix information used by downstream staging. |
| `bext.spdx.json` | Repository dependency inventory for a committed bext revision, including projects outside the active build profile. |
| `bext.cdx.json` | The same source inventory serialized as CycloneDX 1.6 JSON. |

Wrappers install into their designated prefix using normal `bin`, `lib`,
`include`, and `share` layout. Copy bundled legal notices into
`${DOC_LICENSE_DIR}`; retain notices for included third-party components too.

A normal build finalizes the bundle with `strclear` and supported binary
processing tools such as `plief`. It normalizes producer paths and runtime
search paths and writes the install manifest. Building a single dependency
install target does not finalize the full bundle. Finish the normal build
before downstream packaging or relocation tests.

Treat `install/` as read-only when consuming it. BRL-CAD stages copies and makes
its own staging-specific changes. `BRLCAD_EXT_DIR` names the directory holding
both `install/` and `noinstall/`, for example `build/auto/Release` for the `auto`
preset. Requested and physical producer prefixes are recorded for symlink
aliases; test use through a different alias and after moving the bundle.

Keep metadata products distinct. The SPDX inventory records declared source
provenance and dependency relationships from committed metadata; it is not an
inventory of only installed packages or proof of built-file checksums. The
installed manifest and the SPDX integrity-refresh tests address different
parts of the delivery workflow.

## Validation and CI

### Validate the candidate before committing

Metadata has two explicit input modes. `HEAD` (the default) reads committed
wrappers, package descriptors, repository-local evidence, `.deps` files, URLs,
gitlinks, and the reference table from the same
resolved commit. `INDEX` reads their staged versions, rejects conflicted entries,
and supports a new submodule before an integration commit. Neither mode reads
unstaged repository metadata. The SBOM descriptors also inspect Qt attribution
and Tcl/OpenImageIO aggregate license evidence in populated source trees.
Initialize those submodules at the candidate pins before checking the full
repository inventory or generating its SBOM:

```sh
git submodule update --init -- qt/qt tcl/tcl openimageio/oiio
```

The isolated metadata regression fixtures remain offline and do not need
dependency checkouts. When validating staged pin changes, align the inspected
source trees with the staged pins as well.

Stage the integration inputs, then regenerate the table from that staged
snapshot. WRITE updates the working-tree table while preserving surrounding
working-tree prose. Stage that result before the INDEX check:

During snapshot evaluation, omit the submodule path and stage managing files
individually; keep the experimental source tree untracked.

```sh
git add CMakeLists.txt .gitmodules <wrapper-and-patch-paths> <submodule-path>
cmake -DBEXT_SOURCE_DIR="$PWD" -DBEXT_INVENTORY_MODE=INDEX \
  -DBEXT_DOC_MODE=WRITE -P CMake/GenerateDependencyDocs.cmake
git add DEPENDENCIES.md
cmake -DBEXT_SOURCE_DIR="$PWD" -DBEXT_INVENTORY_MODE=INDEX \
  -DBEXT_DOC_MODE=CHECK -P CMake/GenerateDependencyDocs.cmake
git diff --cached --check
git diff --cached --submodule=log
```

The corresponding configured targets are `update_staged_dependency_docs` and
`check_staged_dependency_metadata`. The existing `update_dependency_docs` and
`check_dependency_metadata` targets operate on HEAD metadata. CHECK examines
the table in the selected snapshot, so an unstaged table edit cannot satisfy
an INDEX check. After committing, run the committed metadata check and SBOM:

```sh
cmake -DBEXT_SOURCE_DIR="$PWD" -DBEXT_DOC_MODE=CHECK \
  -P CMake/GenerateDependencyDocs.cmake
cmake -DBEXT_SOURCE_DIR="$PWD" -DBEXT_SBOM_OUTPUT="$PWD/build/bext.spdx.json" \
  -P CMake/GenerateSbom.cmake
```

SBOM generation requires HEAD mode and uses that same commit in its namespace.
It deliberately rejects INDEX mode rather than labeling staged metadata as a
committed artifact. `supply_chain_check` combines the committed check and SBOM.
The metadata parsers are those in the current scripts; when changing those
scripts, exercise their behavior explicitly even if inventory data is committed.

### SBOM formats and local tools

The `sbom` target emits SPDX 2.3 and CycloneDX 1.6 without requiring Python or
external converters. Both writers use the same resolved inventory: the
CycloneDX writer consumes its SPDX-shaped JSON representation, without
re-reading package descriptors or independently resolving identities. For a
standalone invocation, pass both output names:

```sh
cmake -DBEXT_SOURCE_DIR="$PWD" \
  -DBEXT_SBOM_OUTPUT="$PWD/build/sbom-tools/results/bext.spdx.json" \
  -DBEXT_CYCLONEDX_OUTPUT="$PWD/build/sbom-tools/results/bext.cdx.json" \
  -P CMake/GenerateSbom.cmake
```

Add `-DBEXT_SBOM_ALLOW_DIRTY=ON` for an intentional development inventory.
This retains HEAD metadata and labels the document with dirty-tree provenance.
The source checkouts required above must still be populated.

CycloneDX `bom-ref` values retain package SPDX identifiers. Nested components
represent `CONTAINS`; dependency edges represent only `DEPENDS_ON`. The metadata
component describes the whole repository inventory, including inactive groups.
Its lifecycle is `pre-build`. Source aggregates, including Qt, use `library`
rather than implying a runtime container image; the original purpose remains
in `bext:spdx:primaryPackagePurpose`.

CycloneDX licenses use the concluded expression when asserted, otherwise the
declared expression, with the corresponding acknowledgement. `NONE` and
`NOASSERTION` do not become license expressions. Both original assertions,
source provenance, comments, and copyright assertions remain in `bext:spdx:*`
properties. Custom license texts accompany their original identifiers in
license evidence. Serial numbers and timestamps are reproducible.

Install independent validators in a local virtual environment, without admin
access or changes to the system Python:

```sh
python3 -m venv build/sbom-tools/venv
build/sbom-tools/venv/bin/python -m pip install -r CMake/sbom-requirements.txt
build/sbom-tools/venv/bin/python CMake/ValidateSbom.py \
  --spdx build/sbom-tools/results/bext.spdx.json \
  --cyclonedx build/sbom-tools/results/bext.cdx.json
python3 CMake/tests/test_sbom_formats.py -v
```

This runs the official [SPDX validator](https://github.com/spdx/tools-python)
and [CycloneDX strict JSON validator](https://github.com/CycloneDX/cyclonedx-python-lib),
then checks package identity, source downloads, licenses and evidence,
containment, document provenance, and dependency parity. The pinned Python
requirements include JSON validation only; XML libraries are unnecessary.
FreeBSD may compile Python dependencies locally, requiring an available C/Rust
toolchain. Ordinary SBOM generation does not need these validation packages.

For an already configured build, set `BEXT_SBOM_PYTHON` to the virtual
environment's Python at configure time, then build `sbom_validate` or
`sbom_scan_inputs`. The former runs both specification validators and parity;
the latter generates advisory projections and coverage reports. Neither target
builds the dependency libraries. Weekly CI installs the validators explicitly,
runs both formats and projections, and fails on validation errors.

### Manual dependency update reports

Renovate is an optional release-discovery tool here. Neither normal builds nor
CI invoke it automatically. These targets run without compiling dependencies:

```sh
cmake --build build/release --target dependency_update_inputs
cmake --build build/release --target dependency_update_report
```

The first generates inputs without requiring Renovate or network access.
The second requires a Renovate executable on PATH or configured with
`BEXT_RENOVATE_EXECUTABLE`, and performs upstream tag or approved branch lookups. Both write
under the build directory's `dependency-updates` directory. Outputs include
the generated `dependency-updates.json` and `renovate.json`, a readable
`dependency-update-report.txt`, a structured `dependency-update-report.json`,
and a spreadsheet-friendly `dependency-update-report.csv`.
A lookup also keeps JSON logs and stderr for diagnosis. A missing tool or
incomplete lookup returns a failed target and is reported explicitly; it is
never interpreted as an up-to-date dependency.
If Node.js or Renovate is missing, `dependency_update_report` fails and prints
setup commands for the current platform, including the private npm prefix,
the CMake executable setting, and a link to the setup guide. It checks only
the tools needed for update discovery; scanners and Python validators are
independent optional tools. `dependency_update_inputs` needs neither Node.js
nor Renovate.

The adapter copies only its generated inputs to a temporary directory outside
the checkout, clears inherited Renovate configuration and hosting tokens,
and forces `--platform=local --dry-run=lookup`. It disables scripts and
plugins. There are no repository arguments or hosted-platform operations.
Renovate's experimental local platform cannot create branches or pull
requests. No GitHub or Gitea installation is needed. The report is a list of
release candidates, not a compatibility verdict or an update implementation.
It does not update source mirrors, pins, patches, or VEX decisions.

Current versions and upstream PURLs come from the canonical source SBOM,
which is generated from dependency descriptors. Ordinary GitHub/Git PURLs
with version tags produce `git-tags` queries automatically. Dependency-local
`UpdateChecks.json` catalogs supply exceptional policies, without another
current-version pin. Every record has a descriptor `source` path and a `kind`:

* `release` (the default) supports `packageName` (HTTPS Git repository),
  `currentValueFrom` (`ref` or `version`), `versioning`, and `extractVersion`.
  A reviewed native version can be recorded in the descriptor while retaining
  its exact source-commit PURL. Tie newly reviewed versions to the source pin
  with `REVIEWED_REVISION`. Use `baseline: snapshot` when the comparison
  version describes development sources. Without a newer release, this
  reports `snapshot_no_newer_release`, rather than claiming a current release.
* `commit` requires an explicitly approved `branch`. The repository and
  current digest come from committed `.gitmodules` and gitlinks, not from
  the working checkout or an upstream alias. Renovate uses `git-refs` and
  `currentDigest` to check that branch. Equal tips report `commit_current`;
  differing tips report `commit_changed`. Commit IDs are never sorted.
* `parent` names one or more descriptor source paths in `coveredBy`. It
  reports the actual checks covering an aggregate or copied component,
  including failed, manual, or outside-selection checks. Cycles and missing
  targets are rejected. Qt's aggregate follows both Base and SVG; Tcl's
  copied SQLite follows the maintained standalone SQLite dependency.
* `manual` requires a `reason` and reports `manual_import`. Use it when a
  historical import, conflicting version declarations, or an unverified
  release feed still needs investigation. It is an explained coverage gap.

Contained components automatically record their `managedBy` relationship
from SBOM containment. A contained library with its own recognizable upstream
release keeps its independent release check, while its update still goes
through the parent. An unrecognized contained snapshot defaults to a parent
check. Root packages without a usable rule remain `not_checked`. The report
counts check kinds separately from outcomes so parent coverage and manual
imports cannot inflate the independent lookup count.

Commit changes are classified as advances, rewinds, divergence, unrelated
history, or unknown ancestry. The comparison fetches commit history, filtered
to omit trees, into a private bare cache under the report directory. It does
not fetch into dependency checkouts. Unavailable history is visible and makes
the lookup incomplete. Full digests and comparison counts are retained in
JSON; raw Git diagnostics go to the cache's `ancestry.log`.

For maintained imports, a commit check can watch the prepared BRL-CAD branch,
with a `reason` explaining that upstream integration remains a separate task.
Netpbm follows `brlcad`; Lemon and regex follow their maintained `main` branches.
These checks report prepared-source availability, not upstream release coverage.
Rules cannot claim sources owned by another dependency folder. See the
strclear, plief, osmesa, Tcl, SQLite, and Qt catalogs for concrete policies.

Install the CLI as described in
[Setting up the external supply-chain tools](#setting-up-the-external-supply-chain-tools).

Limit a trial run with
`-DBEXT_UPDATE_REPORT_COMPONENTS="zlib;sqlite3;tcl;qt"` at configure time, or
use `--only <dependency>` repeatedly with `CMake/DependencyUpdates.py`.
Filter by consumer group with `-DBEXT_UPDATE_REPORT_GROUPS="BRLCAD;APPLESEED"`,
or repeat `--group BRLCAD --group APPLESEED` with the script. Multiple groups
select their union; a component selection further restricts that result.
Unknown groups and empty intersections fail explicitly.

Every JSON package record includes its `groups` array. Group tags come from
the canonical source SBOM's structured membership annotation, which reflects the
owning dependency's `BextPackage.cmake` declaration, including embedded copies.
The text report labels every package and summarizes release and commit
candidates by group. JSON includes the same summaries in `byGroup`, plus
unique overall totals. CSV includes all selected records with semicolon-separated
groups, status, current version or commit, candidates, and source identity.
Shared dependencies retain all their tags, so group totals overlap. When
filtering groups, `byGroup` summarizes only requested groups, while each record
retains its complete membership. `UNGROUPED` selects and displays dependencies
with no declared group gate (the source SBOM calls these `always considered`);
their JSON `groups` array remains empty.

SPDX stores this machine-readable value in a `Tool: bext:membership` annotation
with `schemaVersion`, `component`, and `groups`. CycloneDX preserves it as the
`bext:membership` property. Human-readable package comments are independent.
Reports reject missing, ambiguous, or invalid annotations; regenerate an older
source inventory before using it with the report adapter.

The JSON report records the source file SHA-256, resolved policy SHA-256,
observed and tested Renovate versions, and start/finish timestamps. The adapter
contract is checked against captured results from Renovate 44.221.6. Other
versions require compatibility testing; local mode remains experimental.
Set `BEXT_UPDATE_LOOKUP_TIMEOUT` (default 1800 seconds) and
`BEXT_UPDATE_ANCESTRY_TIMEOUT` (default 300 seconds per Git command), or use
`--lookup-timeout` and `--ancestry-timeout` directly. Outputs are staged before
publication, with the JSON completion report replaced last.

Report status `generated` means only inputs were prepared. `complete` means
the configured lookups completed, and can coexist with `manual_import`,
`parent_managed`, and `not_checked` coverage gaps. `current` means a valid
release lookup returned no candidate; commit equality is `commit_current`.
Malformed results, lookup errors, and no recognizable releases become
`lookup_failed`. Missing results or unknown ancestry make the report
`incomplete`; tool failures/timeouts produce `failed`, and an absent optional
executable produces `tool_unavailable`. These unsuccessful lookups return a
nonzero exit code. None establishes dependency compatibility.

Groups describe declared membership, rather than complete build profiles.
For example, a BRL-CAD build may also use packages in QT, TCL, and GDAL;
include those groups when reviewing that larger set. Ungrouped build tools
remain visible in an unfiltered report or with `--group UNGROUPED`.
Without a selection, the report covers all source-inventory packages,
including embedded copies that may be excluded by the actual build.
Review the coverage, lookup failures, major-version changes, and related
updates before choosing a candidate set. Coupled updates need joint bext and
BRL-CAD integration tests; successful lookup does not establish compatibility.

See [Renovate's local mode](https://docs.renovatebot.com/modules/platform/local/),
[JSONata custom managers](https://docs.renovatebot.com/modules/manager/jsonata/),
and [dry-run controls](https://docs.renovatebot.com/self-hosted-configuration/#dryrun),
and [Git-ref digest lookups](https://docs.renovatebot.com/modules/datasource/git-refs/).

### Advisory identities and scanner coverage

Upstream identity and source provenance serve different purposes. Package
descriptors already record upstream URLs and release PURLs separately from
the exact vendored download locations and commits. Use that upstream identity
when selecting advisory aliases; do not infer identity from a local fork's
name. Tools can still require a package ecosystem identity such as Conan
instead of an upstream GitHub PURL.

Dependency-local `SbomScanAliases.json` files record exact source PURL to
advisory PURL mappings. Put mappings with the upstream dependency's wrapper,
or with the vendoring wrapper when that upstream has no separate wrapper.
A shared upstream identity needs only one authoritative mapping, even when
multiple components contain it. `CMake/SbomScanProfiles.json` defines the
ecosystem types accepted by each profile. The initial `conan` profile is
useful with Trivy and can also be supplied to other consumers.

The projector discovers these catalogs without a central dependency list.
Identical mappings shared by catalogs are accepted; conflicting mappings and
duplicate entries within a catalog are rejected. The aggregate digest depends
on the selected mappings, not their filesystem locations. `--aliases` can
select another bext source root or an explicit self-contained catalog with
its own `profiles` and `aliases` fields.
Every entry includes pinned recipe evidence identifying the same upstream
release and an explanation of the mapping. New versions require new evidence;
the projection rejects mismatched versions and ambiguous aliases. Do not map
an arbitrary commit, embedded subpath, or downstream fork to a release merely
because the names resemble each other.

```sh
for format in spdx cdx; do
  python3 CMake/ProjectSbom.py \
    --input "build/sbom-tools/results/bext.$format.json" \
    --output "build/sbom-tools/results/bext.conan.$format.json" \
    --report "build/sbom-tools/results/coverage-$format.json"
done
```

The separate, labelled projections preserve the source documents. SPDX keeps
the canonical PURL as an additional reference and records alias provenance in
annotations. CycloneDX keeps the original name and PURL in properties and uses
a flat component list, retaining containment in `bext:source:parent` properties.
This accommodates consumers that ignore nested CycloneDX components. The
projection uses the ecosystem lookup name as well as its PURL, because some
scanners match names independently. Graphs, source revisions, and source
download locations remain intact. A matching alias identifies advisory
candidates; it does not claim the library was installed through that package
manager or that an upstream vulnerability applies after local patches.

Reports enumerate mapped and unmapped packages and distinct mapped PURLs.
Mapping coverage is not proof of advisory database coverage. Compare those
reports with actual scanner package counts; consumers may deduplicate repeated
occurrences of the same upstream release. An empty vulnerability result is
meaningful only with understood scan coverage.

### Build inventories and VEX

A configured build requires Python 3.8 or newer for finalization. The
standalone source-inventory commands still require only CMake. Finalization
now generates build inventories and OpenVEX automatically:

```sh
cmake --build build/release --target bext_finalize
```

For `BEXT_DISCARD_WORK=ON`, build the normal `bext_release` target instead.
The post-install evidence step runs before source and build directories are
discarded; its receipt survives in the top-level build directory. Reviews and
build logic are covered by the immutable release-plan input checks.

Alongside the install tree and component manifests, the configured install
prefix receives:

* `bext.build.spdx.json` and `bext.build.cdx.json`: finalized installed
  dependencies, with build-specific identities.
* `bext.build.conan.spdx.json` and `bext.build.conan.cdx.json`: scanner
  projections, with corresponding `.coverage.json` reports.
* `bext.openvex.json`: applicability statements for installed reviewed
  components. No document is emitted when there are no such components,
  because OpenVEX requires a nonempty statement list.
* `bext-vex-evidence.json`: portable review records, captured source facts,
  finalized file hashes, and the decisions established by this build.
* `bext-vex-report.json`: applied reviews, reviews needing attention,
  components not installed, and packages with no review records.

Validate a finalized ownership manifest with the SBOM validation environment:

```sh
python3 CMake/ValidateSbom.py \
  --component-manifest build/release/bext-component-manifest.json
```

Every package record declares `output` as `install` or `noinstall`.
The schema also accepts `source_spdx_id` for downstream identity remapping.

Canonical source inventories remain unchanged. An installed-product inventory
excludes `noinstall` tools and packages removed by build selectors, including
Tcl database packages when those are disabled. It describes bundled artifacts;
system dependencies require separate provenance and inventory work.

Each built package retains its upstream PURL in annotations or properties and
adds a `bext_build` qualifier to its primary PURL. This qualifier fingerprints
the finalized files, platform, package provenance, and product context. Tcl's
private SQLite and the standalone SQLite library therefore receive distinct
identities. Conan projections preserve the qualifier. The OpenVEX document
names both the canonical and mapped qualified PURLs, allowing both scanner
views to use the same decisions without asserting anything about every copy
of that upstream release.

### Maintaining applicability reviews

Maintain reviewed decisions in each wrapper's `VexReviews.json`. These are
review inputs, not scanner ignore lists. The initial records cover SQLite's
CLI `.recover` finding (`CVE-2026-119586`) for the standalone and Tcl libraries,
and Qt's patched CBOR issue (`CVE-2026-105924`). The SQLite shell implementation
is absent from the shipped libraries; the shell build tool remains outside
the bundled output. Qt's `fixed` decision requires the reviewed patch in the
staged source. Neither conclusion is inferred from a version string alone.

Each catalog has `schemaVersion: 1`, the wrapper `component`, its
ExternalProject `target`, and a nonempty `reviews` list. Each review records:

* A stable `id`, canonical SPDX `package` ID and unqualified `sourcePurl`,
  CVE `vulnerability`, `status`, `scope`, `impactStatement`, UTC `reviewedAt`,
  and HTTPS `references` supporting the analysis.
* A standard OpenVEX `justification` for `not_affected`, or an
  `actionStatement` for `affected`.
* `conditions.sources`: reviewed submodule paths and full Git revisions.
* `conditions.inputs`: allowed source-preparation input paths and SHA-256
  hashes, including wrapper logic, patches, and files copied into sources.
  `requiredInputs` identifies the inputs that must actually be used. An
  unexpected applied patch also invalidates a review.
* `conditions.stagedFiles`: root-relative staged source paths and SHA-256
  hashes after copying and patching.
* `conditions.requiredArtifacts`: a list of alternative-pattern groups.
  Every group needs an installed match. Optional `forbiddenArtifacts`
  patterns reject packaging that contradicts the decision.

All recorded paths use relative POSIX syntax. Artifact patterns are matched
against finalized component-owned paths, using case-sensitive shell glob
rules. The catalog validator in `CMake/BextVex.py` rejects unknown fields,
malformed identities, and incomplete conditions. See the existing catalogs
for concrete records rather than creating a separate per-scanner exception.

An ExternalProject post-install step captures clean source revisions, the
inputs actually used by source preparation, relevant staged files, and
installed artifact hashes. The finalizer binds this receipt to the files it
processes, then records their finalized hashes. Repeated finalization can
reuse previously established evidence only while those finalized bytes and
the capture still match. Failed generation removes earlier assertions.

A changed revision, dirty source checkout, changed or additional input,
missing artifact, or mismatched evidence produces `under_investigation`
and a `review_needed` report entry. It does not suppress the finding. Inspect
the report after an update, review the source and build changes, update the
conditions and review date, and rebuild the affected dependency. Refreshing
hashes alone is not an applicability review. Unrelated documentation commits
do not invalidate unchanged component facts.

Use `scope: component` for facts independent of callers, such as absent code
or an applied fix. Component-scoped `not_affected` reviews allow only
`vulnerable_code_not_present` or `component_not_present`. Conclusions about
execution paths, adversary control, or caller mitigations require
`scope: product`, a `product` name, and the exact `conditions.productContext`
digest reported by the generator. Such decisions require local review for a
new product context and are never silently inherited downstream.

### Scanning with VEX

With Grype on PATH and its local database populated, the build target keeps
raw and filtered JSON reports, scanner logs, and an audit summary under
`bext-vex-scans`:

```sh
cmake --build build/release --target vex_scan
```

The scanner wrapper also accepts either finalized SBOM format and supports
Trivy. For example, using the documented local tool environment:

```sh
. build/sbom-tools/env.sh
python3 CMake/ScanVex.py \
  --scanner grype --offline \
  --input build/release/bext.build.spdx.json \
  --vex build/release/bext.openvex.json \
  --output-dir build/release/grype-results
python3 CMake/ScanVex.py \
  --scanner trivy --offline \
  --input build/release/bext.build.conan.cdx.json \
  --vex build/release/bext.openvex.json \
  --output-dir build/release/trivy-results
```

Omit `--offline` to allow a database refresh before the baseline scan.
The filtered scan reuses that database. The wrapper uses an empty scanner
configuration and ignore file, clears common ambient ignore/VEX filters,
and records suppressed findings separately in the summary. Missing VEX is
valid for builds with no installed reviewed packages: both reports then
contain the baseline findings. Review `bext-vex-report.json` as well as the
scanner reports; an empty vulnerability report is not evidence of coverage.

Trivy 0.76.2 reports vulnerabilities for only the first instance when multiple
packages share an advisory lookup name and version, even with different
build qualifiers. The wrapper partitions repeated variants into separate
scans and merges their reports, retaining the native per-partition reports,
logs, and SBOMs for audit. Use this workflow for Trivy when variants repeat;
a direct scan of the combined inventory can omit an unreviewed copy.
Grype 0.121.2 preserves those variants in the tested inventories.

The offline generator tests exercise evidence invalidation, import rules,
format parity, empty builds, and failed-publication cleanup. Scanner tests
also check that a reviewed copy can be filtered while another copy of the
same version and unrelated CVEs remain visible, in both formats:

```sh
python3 CMake/tests/test_vex_generation.py -v
BEXT_VEX_SCANNER_TESTS=1 python3 CMake/tests/test_vex_scanners.py -v
```

The scanner tests make no database updates and are skipped by default.

### Reusing bext evidence in BRL-CAD

BRL-CAD can import `bext-vex-evidence.json`, combine its canonical SPDX source
inventory with its own finalized component manifest, and generate statements
for its final package selection:

```sh
python3 CMake/GenerateVex.py \
  --product brlcad --author https://brlcad.org/ \
  --sbom build/brlcad.spdx.json \
  --manifest build/brlcad-component-manifest.json \
  --install-root build/install \
  --import-evidence build/bext-vex-evidence.json \
  --output-dir build/release-metadata
```

The manifest uses the existing
`https://brlcad.org/schema/bext-component-manifest-v2` structure: `platform`,
`files` containing `path` and `component`, and `packages` containing
`spdx_id`, `component`, and `output` (`install` or `noinstall`). If BRL-CAD
renames an imported SPDX package ID, include its original bext ID as
`source_spdx_id`. Keep the corresponding upstream PURL unchanged. Paths are
relative to the final install root, and files must have explicit owners.

Only decisions established by the exported build can be reused. Imported
component files may be omitted or relocated, but each retained file must
match an exported SHA-256 hash. Changed or additional component artifacts
require new evidence. Reused statements receive the new product's build
qualifiers. Product-scoped reviews require local reanalysis, and system
libraries cannot inherit a bext-built library's decision by version match.
This supplies the import interface; BRL-CAD's own build integration must
provide its final inventory and ownership manifest.

Release the matching SPDX, CycloneDX, OpenVEX, and evidence files together,
using the project's existing release publication and signing process.
The approach follows established vendoring practices: keep provenance and
local changes with dependency recipes, then evaluate applicability for the
built product. See [Chromium's dependency guidance](https://chromium.googlesource.com/chromium/src/+/main/docs/adding_to_third_party.md),
[Yocto's vulnerability workflow](https://docs.yoctoproject.org/dev/security-manual/vulnerabilities.html),
the [OpenVEX specification](https://github.com/openvex/spec/blob/main/OPENVEX-SPEC.md),
[Grype filtering documentation](https://oss.anchore.com/docs/guides/vulnerability/filter-results/),
and [Trivy VEX documentation](https://trivy.dev/docs/latest/supply-chain/vex/file/).

| Tool | Use with bext | Setup without admin access |
| --- | --- | --- |
| [Grype](https://github.com/anchore/grype) | Scan both formats, including the reviewed CPEs already emitted by bext. Triage upstream matches against patches and build selection. | A native Go source build works on FreeBSD; official release binaries cover Linux, macOS, and Windows. |
| [Trivy](https://trivy.dev/docs/latest/target/sbom/) | Exercise ecosystem aliases. The tested release does not scan our original `github`, `git`, and `generic` PURLs or use SPDX CPE references for matching. | Native FreeBSD release archive; extract into a user-owned directory and verify its published checksum. |
| [sbomqs](https://github.com/interlynk-io/sbomqs) | Inspect quality and missing metadata in both formats. Interpret scores against the purpose of a source inventory. | Native Go source build works on FreeBSD. |
| [Syft](https://github.com/anchore/syft) | Independently read the output or compare an artifact scan with declared metadata. Conversion is useful for experiments; check for lost information. | Native Go source build works on FreeBSD. |
| [sbomdiff](https://github.com/anthonyharrison/sbomdiff), [sbom2dot](https://github.com/anthonyharrison/sbom2dot) | Compare component versions/licenses and draw dependency graphs. These complement specification and parity checks. | Install in the same virtual environment; render DOT with Graphviz if available. |
| [CycloneDX CLI](https://github.com/CycloneDX/cyclonedx-cli) | Additional conversion, diff, merge, and signature experiments. Cross-format conversion can lose information. | Official releases cover Linux, macOS, and Windows; use those hosts for the prebuilt CLI. |

For example, with Go available (some FreeBSD installations name it `go127`),
install the tested Go tools under the build directory:

```sh
mkdir -p build/sbom-tools/bin
GOBIN="$PWD/build/sbom-tools/bin" go127 install github.com/anchore/grype/cmd/grype@v0.121.2
GOBIN="$PWD/build/sbom-tools/bin" go127 install github.com/anchore/syft/cmd/syft@v1.57.0
GOBIN="$PWD/build/sbom-tools/bin" go127 install github.com/interlynk-io/sbomqs/v2@v2.1.3
build/sbom-tools/venv/bin/python -m pip install sbomdiff==0.6.0 sbom2dot==0.3.2
```

Keep vulnerability databases in user-owned directories. Initial downloads need
network access and substantial disk space; subsequent scans can reuse them:

```sh
GRYPE_DB_CACHE_DIR="$PWD/build/sbom-tools/grype-cache" \
  build/sbom-tools/bin/grype sbom:build/sbom-tools/results/bext.spdx.json -o json \
  > build/sbom-tools/results/grype-spdx.json
build/sbom-tools/bin/trivy --cache-dir build/sbom-tools/trivy-cache sbom \
  --format json --output build/sbom-tools/results/trivy-conan.json \
  build/sbom-tools/results/bext.conan.spdx.json
build/sbom-tools/bin/sbomqs score --json build/sbom-tools/results/bext.spdx.json \
  > build/sbom-tools/results/quality-spdx.json
```

Trivy's [`github`/`generic` PURL coverage](https://github.com/aquasecurity/trivy/blob/v0.76.2/pkg/purl/purl.go)
and [SPDX reference handling](https://github.com/aquasecurity/trivy/blob/v0.76.2/pkg/sbom/spdx/unmarshal.go)
explain why successful parsing of the canonical source inventory can produce
zero scanned packages. Keep a known-vulnerable synthetic fixture separate
from release inventories when testing scanner matching; never change real
dependency versions to manufacture a finding.

The checked-in positive control exercises ecosystem matching without fetching
or building vulnerable source code:

```sh
build/sbom-tools/bin/trivy --cache-dir build/sbom-tools/trivy-cache sbom \
  CMake/tests/fixtures/vulnerable-zlib.spdx.json
```

With the tested database this reports `CVE-2018-25032` and `CVE-2022-37434`.
This fixture also supplies a CPE for a Grype positive control. It must never be
included in release inventories or interpreted as the project's actual zlib
version. Advisory counts and severities can change as databases are updated.

### Match checks to the change

| Change | Relevant evidence |
| --- | --- |
| New/changed wrapper selection | Default detection, `ENABLE_ALL`, explicit OFF, component inclusion/exclusion and reconfiguration, inactive groups; snapshot absent/present where applicable. |
| Source pin or patch update | Clean targeted build, representative consumers, notices and installed layout, intended system/bundled prerequisites, and proposed source availability. |
| Shared scheduling or cleanup | Offline release-build tests; native MSBuild plus Ninja, Debug and Release, failure/resume, and retained installs. |
| Finalization or staging | Finalized bundle, relocated consumer, ELF staging regression where applicable, installed SPDX integrity, and platform-specific binary checks. |
| Metadata or documentation | HEAD and INDEX checks, generated table, source-mode regression tests, working links, current preset paths, and a runnable example. |

Useful offline regressions:

```sh
python3 CMake/tests/test_dependency_selection.py -v
python3 CMake/tests/test_dependency_metadata.py -v
python3 CMake/tests/test_release_build.py -v
```

Run `tests/spdx_integrity.cmake` with an unused `TEST_ROOT` for integrity-refresh
changes. The ELF staging/relocation test needs BRL-CAD, built helper tools, and
other prerequisites; its invocation is documented in README.md. On Windows,
`dll_typecheck` and `dll_loadcheck` provide additional checks where relevant.
Do not describe a skipped platform test as having passed.

Metadata validation finds missing source declarations/pins, unknown edges,
cycles, and missing license-install declarations. It does not compile the
packages, validate license compatibility, or replace consumer testing.

CI coverage is defined by [.github/workflows](.github/workflows). `check.yml`
runs the platform Debug builds on push. `binary_dependencies.yml` builds and
packages Release dependencies on push and eligible scheduled runs.
`weekly.yml` supplies extended preset, metadata, regression, and native MSBuild
coverage on eligible weekly runs or manual dispatch. Inspect the workflow
conditions for a particular change; a push does not imply every extended check
ran. Use both minimal system environments and systems with installed packages
when assessing fallback selection.

## Troubleshooting and reference

| Symptom | Where to look and what to do |
| --- | --- |
| Wrong source revision | Compare HEAD, index, and submodule checkout separately. Review mirror mappings and align the checkout explicitly. |
| Patch failure or an edit not taking effect | Inspect the ExternalProject patch step, shared `patch-rejects` artifacts, patch order, and the selected upstream release. Register every submodule patch in `PATCH_FILES`. For a non-submodule snapshot, recreate the experimental build tree after patch/source edits. |
| Configure/build/install failure | Identify the failing layer and dependency; inspect its ExternalProject stamp/log directory. `EXT_BUILD_VERBOSE=ON` exposes step output. |
| Missing `*_BLD.vcxproj` before dependency configure | Inspect superbuild target discovery and forwarding targets, rather than deleting upstream IDE project files. |
| Staged metadata differs from a check | Select INDEX mode, stage every intended input and the regenerated table, and resolve index conflicts. HEAD intentionally describes the committed state. |
| Disabled dependency still appears installed | Installed products can outlive selection changes. Use a fresh build/install tree rather than treating old files as proof of current selection. |
| Discard build rejects changed inputs or outputs | Use a fresh build directory and install prefix for the new recipe. Preserve failed working trees and logs for diagnosis. |
| Discard build failed with unchanged inputs | Repeat the build to resume. Completed projects are skipped; failed work is retained. Inspect `bext-release-logs`. |
| Prefix/build lock is busy | Check for an active build using that prefix or directory; do not run concurrent discard drivers against it. |
| Relocated bundle fails | Finish finalization, inspect recorded producer prefixes and runtime paths, then reproduce with a copied/moved bundle and consumer. |

With Ninja and Makefile generators, the normal `clean` target resets generated
ExternalProject state while retaining installed outputs and top-level control
files. In discard mode it also resets completion state. Cleaning does not
remove stale installed products or convert an old output tree into a new recipe.

Use Git's maintained references for [submodule operations](https://git-scm.com/docs/git-submodule)
and [.gitmodules configuration](https://git-scm.com/docs/gitmodules). Examples:

```sh
# Configure only the intended path's branch policy for an exception.
git submodule set-branch --branch RELEASE -- <dependency>/<source>

# Inspect populated dependencies including ignored dirty worktrees.
git status --short --ignore-submodules=none

# Optional local fetch concurrency, independent of build parallelism.
git config --local submodule.fetchJobs 0
git config --local fetch.parallel 0
```

Tracking-branch configuration affects `update --remote`, not an ordinary
checkout of bext's recorded pin. Do not use a repository-wide remote update as
a routine single-dependency upgrade. A full-history development clone is
preferable when comparing releases and maintaining fork history; shallow
compile-only checkouts may not contain release tags or older pins.

## Example: pugixml from local snapshot to submodule

Pugixml is already integrated. This example illustrates how to develop an
integration for a new dependency; do not add a second copy to an existing
checkout. It has no library prerequisites and a compact
[maintained wrapper](pugixml/CMakeLists.txt). Upstream
[release v1.16](https://github.com/zeux/pugixml/releases/tag/v1.16) resolves to
`c8033ce9d039e7f9d134877c363397b3cfe20816`, matching the pin used here.

### Evaluate the released source

In a separate source checkout, select the release and verify its resolved
commit before making a plain snapshot:

```sh
git clone --branch v1.16 https://github.com/zeux/pugixml "$HOME/pugixml-eval"
git -C "$HOME/pugixml-eval" rev-parse 'v1.16^{commit}'
cmake -S "$HOME/pugixml-eval" -B "$HOME/pugixml-eval-build" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DPUGIXML_BUILD_TESTS=OFF
cmake --build "$HOME/pugixml-eval-build" --config Release --parallel 2
```

In the experimental bext branch:

```sh
mkdir -p pugixml/pugixml
printf 'PATCH\n' > pugixml/pugixml.deps
git -C "$HOME/pugixml-eval" archive HEAD | tar -x -C pugixml/pugixml
```

Keep the plain source snapshot untracked. Register the wrapper before its
consumers, including AssetImport and OSL:

```cmake
add_project(pugixml GROUPS "BRLCAD;APPLESEED")
```

Use this experimental `pugixml/CMakeLists.txt`. The literal revision declaration
is provenance, not a request to fetch it. This release needs no adaptations
for the example, so its patch list starts empty. If testing an adaptation, add
its patch file to that list in application order; the command builder also
accepts an empty list.

```cmake
bext_local_source(PUGIXML pugixml https://github.com/zeux/pugixml c8033ce9d039e7f9d134877c363397b3cfe20816)

if (ENABLE_PUGIXML)
  RegisterDeps(PUGIXML)
  set(PUGIXML_PATCH_FILES)
  bext_patch_command(PUGIXML_PATCH_COMMAND ${PUGIXML_PATCH_FILES})
  ExternalProject_Add(PUGIXML_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/pugixml"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    PATCH_COMMAND ${PUGIXML_PATCH_COMMAND}
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBUILD_SHARED_LIBS=ON
    -DPUGIXML_BUILD_SHARED_AND_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DPUGIXML_BUILD_TESTS=OFF
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
  )
  TargetInstallDeps(PUGIXML PUGIXML_DEPENDS)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/pugixml/LICENSE.md
    ${DOC_LICENSE_DIR}/pugixml.txt
    COPYONLY
  )
endif ()
```

Configure a dedicated incremental test tree and build the target. Before
repeating this sequence after snapshot or patch edits, remove that disposable
tree with `cmake -E rm -rf build/pugixml-eval`. The plain source under
`pugixml/pugixml` is preserved:

```sh
cmake --preset minimal -B build/pugixml-eval -DENABLE_PUGIXML=ON
cmake --build build/pugixml-eval --target PUGIXML_BLD --config Release --parallel 2
cmake -DPROFILE=minimal -DLIST_ONLY=ON -P CMake/BextBootstrap.cmake
```

Other in-scope dependencies are considered during configure. The targeted
build limits compilation to pugixml and its prerequisites. Verify installed
headers, libraries, CMake package files, and
`share/doc/legal/other/pugixml.txt`. Test absent source, explicit OFF,
`ENABLE_ALL`, and a source appearing after the first configure. An absent or
disabled snapshot must produce no local target. Bootstrap excludes the
snapshot wrapper. Stage only the integration files and run INDEX validation.

### Adopt the tested release

First preserve upstream's `v1.16` tag and its commit in the BRL-CAD mirror and
verify a fresh checkout from that mirror, following the source-preparation
procedure. Only after that succeeds, preserve the test snapshot outside the
wrapper and add the source as a submodule, without tracking a moving branch:

```sh
mv pugixml/pugixml "$HOME/pugixml-tested-snapshot"
git submodule add https://github.com/BRL-CAD/pugixml pugixml/pugixml
git -C pugixml/pugixml checkout --detach c8033ce9d039e7f9d134877c363397b3cfe20816
```

Set `ignore = dirty` in the new `.gitmodules` entry. Replace the local-source
helper with the current wrapper's component and ordinary package selection:

```cmake
cad_enable(PUGIXML "libgcv;librt")
bext_enable(PUGIXML)
```

Add the initializer inside the enabled block before `RegisterDeps`:

```cmake
git_submodule_init(pugixml CMakeLists.txt)
```

If the experiment added patches, retain the nonempty `PUGIXML_PATCH_FILES`
list and replace both the standalone `bext_patch_command` call and the
initializer above with:

```cmake
git_submodule_init(pugixml CMakeLists.txt
  PATCH_FILES ${PUGIXML_PATCH_FILES}
  PATCH_COMMAND_VAR PUGIXML_PATCH_COMMAND)
```

Define the list before the initializer, and retain
`PATCH_COMMAND ${PUGIXML_PATCH_COMMAND}` in `ExternalProject_Add`. The adopted
wrapper now tracks patch changes as well as the submodule revision.

Verify system discovery using the package's actual naming or an appropriate
find module; a new dependency's component list must reflect its consumers.
Use a fresh build so snapshot preferences do not mask ordinary detection.
Repeat the relevant selection, platform, and consumer checks, stage the
integration including the gitlink, regenerate/stage the table, and run INDEX
validation. Commit the tested pin and wrapper together, then check HEAD
metadata and generate the SBOM. Finish a normal build and test a relocated
bundle before using it for downstream distribution.
