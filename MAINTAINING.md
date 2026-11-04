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

Stage the wrapper, patches, dependency edges, top-level registration,
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
| `bext_local_source(PKG path url revision)` | Build a permitted, present CMake snapshot; skip an absent one. Cache the preference separately from availability. |
| `git_submodule_init(path checkfile)` | Populate an adopted source when its checkfile is absent, using bext's Git mappings. Call inside the enabled block. |
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
* Use the shared `PATCH_EXECUTABLE` command list and `PATCH_OPTIONS` rather than
  assuming a platform patch executable or GNU-only flags. The shared wrapper
  handles applicability checks and reject artifacts. Itk's custom patch driver
  is an example for integrations needing additional processing.
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
when prior outputs could mask a result. Source revision stamps may reset a
wrapper's generated build directory; they do not prove an old install tree has
been purged of obsolete products.

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
wrappers, `.deps` files, URLs, gitlinks, and the reference table from the same
resolved commit. `INDEX` reads their staged versions, rejects conflicted entries,
and supports a new submodule before an integration commit. Neither mode reads
unstaged source metadata. Checks do not require populated dependency sources.

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
| Patch failure | Inspect the ExternalProject patch step, shared `patch-rejects` artifacts, patch order, and the selected upstream release. Reproduce on a fresh staged copy. |
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
is provenance, not a request to fetch it. Add a `PATCH_COMMAND` using the shared
patch tool if the release needs adaptations, following the wrapper conventions.

```cmake
bext_local_source(PUGIXML pugixml https://github.com/zeux/pugixml c8033ce9d039e7f9d134877c363397b3cfe20816)

if (ENABLE_PUGIXML)
  RegisterDeps(PUGIXML)
  ExternalProject_Add(PUGIXML_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/pugixml"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
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

Configure an incremental test tree and build the target:

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

Verify system discovery using the package's actual naming or an appropriate
find module; a new dependency's component list must reflect its consumers.
Use a fresh build so snapshot preferences do not mask ordinary detection.
Repeat the relevant selection, platform, and consumer checks, stage the
integration including the gitlink, regenerate/stage the table, and run INDEX
validation. Commit the tested pin and wrapper together, then check HEAD
metadata and generate the SBOM. Finish a normal build and test a relocated
bundle before using it for downstream distribution.
