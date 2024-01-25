# bext - Notes

When using submodules, there are some fairly non-intuitive aspects of managing them that need to be taken into consideration:

# Adding a submodule (using Tcl as an example)
```
user@linux:~/bext (main) $ cd tcl
user@linux:~/bext/tcl (main) $ git submodule add -b RELEASE https://github.com/BRL-CAD/tcl.git
```
Edit the new .gitmodules entry to add the "shallow = true" and "ignore = dirty" lines, git add the updated .gitmodules file, and commit the addition of the new submodule.


# Finding the currently referenced submodule SHA1

Git stores a SHA1 to the upstream commit it will target, but this SHA1 isn't readily visible in the working git clone's files.  To see it, per https://stackoverflow.com/a/5033973/2037687) use git ls-tree - for example, this prints the current Tcl SHA1:
```
user@linux:~/bext (main) $ git ls-tree main tcl/tcl
160000 commit 338c6692672696a76b6cb4073820426406c6f3f9	tcl/tcl
```

# Updating a submodule to a newer upstream

The operation of updating submodules requires a full git clone, rather than the shallow
checkouts used in normal operation:
```
user@linux:~ $ git clone --recurse-submodules git@github.com:BRL-CAD/bext.git
user@linux:~ $ cd bext
user@linux:~/bext (main) $ git submodule update --remote
Submodule path 'assetimport/assimp': checked out '6a08c39e3a91ef385e76515cfad86aca4bfd57ff'
Submodule path 'lief/LIEF': checked out '6e4722624adffdbf2e8156d4b8b69aebb8a3c754'
Submodule path 'qt/qt': checked out 'c9e69df410c79e6bc7b8be0f2d35abf366879d50'
user@linux:~/bext (main) $ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   assetimport/assimp (new commits)
	modified:   lief/LIEF (new commits)
	modified:   qt/qt (new commits)

no changes added to commit (use "git add" and/or "git commit -a")
user@linux:~/bext (main) $ git add assetimport/assimp lief/LIEF qt/qt
user@linux:~/bext (main) $ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   assetimport/assimp
	modified:   lief/LIEF
	modified:   qt/qt
user@linux:~/bext (main) $ git commit -m "Update submodule references for AssetImport, LIEF and Qt"
user@linux:~/bext (main) $ git push
```

# Changing the branch of a submodule

https://stackoverflow.com/questions/29882960/changing-an-existing-submodules-branch

# Removing a submodule

As summarized by https://gist.github.com/myusuf3/7f645819ded92bda6677 (using tcl/tcl as an example):

* Delete the .gitmodules entry for the submodule being removed
* git add .gitmodules
* Delete the .git/config entry for the submodule being removed
* git rm --cached tcl/tcl
* rm -rf .git/modules/tcl/tcl
* git commit -m "Removing Tcl submodule"
* rm -rf tcl/tcl

# Updating the BRL-CAD copy of a submodule

The bext repository does not hold BRL-CAD's copies of the various source repositories used -
rather, it points to local repositories in BRL-CAD's project that hold them.  This allows,
among other things, for a lighter footprint for a working checkout.  It also gives us the
opportunity to keep the BRL-CAD copy in sync with upstream sources using the git and github
tools intended for those use cases.

To update (for example) BRL-CAD's copy of GDAL to reference the latest release:
```
user@linux:~ $ git clone git@github.com:BRL-CAD/gdal.git
user@linux:~ $ cd gdal
user@linux:~/gdal (master) $ git remote add upstream https://github.com/OSGeo/gdal
user@linux:~/gdal (master) $ git fetch upstream
remote: Enumerating objects: 4536, done.
remote: Counting objects: 100% (4132/4132), done.
remote: Compressing objects: 100% (986/986), done.
remote: Total 4536 (delta 3297), reused 3885 (delta 3141), pack-reused 404
Receiving objects: 100% (4536/4536), 6.70 MiB | 25.98 MiB/s, done.
Resolving deltas: 100% (3383/3383), completed with 505 local objects.
From https://github.com/OSGeo/gdal
 * [new branch]            backport-7740-to-release/3.7 -> upstream/backport-7740-to-release/3.7
 * [new branch]            master                       -> upstream/master
<snip>
 * [new branch]            vendor/1.4-esri              -> upstream/vendor/1.4-esri
 * [new tag]               v3.7.3                       -> v3.7.3
 * [new tag]               v3.7.3RC1                    -> v3.7.3RC1
 * [new tag]               v3.8.0beta1                  -> v3.8.0beta1
user@linux:~/gdal (master) $ git push --tags
Enumerating objects: 10565, done.
Counting objects: 100% (5511/5511), done.
Delta compression using up to 12 threads
Compressing objects: 100% (1354/1354), done.
Writing objects: 100% (4057/4057), 2.14 MiB | 10.63 MiB/s, done.
Total 4057 (delta 3407), reused 3324 (delta 2699), pack-reused 0
remote: Resolving deltas: 100% (3407/3407), completed with 641 local objects.
To github.com:BRL-CAD/gdal.git
 * [new tag]               v3.7.3 -> v3.7.3
 * [new tag]               v3.7.3RC1 -> v3.7.3RC1
 * [new tag]               v3.8.0beta1 -> v3.8.0beta1
user@linux:~/gdal (master) $ git checkout RELEASE
branch 'RELEASE' set up to track 'origin/RELEASE'.
Switched to a new branch 'RELEASE'
user@linux:~/gdal (RELEASE) $ git merge v3.7.3
Updating f74cd41441..6133cf34a7
Fast-forward
 .github/workflows/alpine/Dockerfile.ci                      |   3 +-
 .github/workflows/cmake_builds.yml                          |  11 ++-
<snip>
 create mode 100644 autotest/ogr/data/shp/multipolygon_as_invalid_polygon.shp
 create mode 100644 autotest/ogr/data/shp/multipolygon_as_invalid_polygon.shx
user@linux:~/gdal (RELEASE) $ git status
On branch RELEASE
Your branch is ahead of 'origin/RELEASE' by 90 commits.
  (use "git push" to publish your local commits)

nothing to commit, working tree clean
user@linux:~/gdal (RELEASE) $ git diff v3.7.3
user@linux:~/gdal (RELEASE) $ git push
Total 0 (delta 0), reused 0 (delta 0), pack-reused 0
To github.com:BRL-CAD/gdal.git
   f74cd41441..6133cf34a7  RELEASE -> RELEASE
```
After this process, the bext repo should be updated with the procedure documented
earlier to update its reference to the gdal RELEASE HEAD:
```
user@linux:~/bext (main) $ git submodule update --remote
remote: Enumerating objects: 1619, done.
remote: Counting objects: 100% (990/990), done.
remote: Compressing objects: 100% (238/238), done.
remote: Total 398 (delta 322), reused 229 (delta 158), pack-reused 0
Receiving objects: 100% (398/398), 156.17 KiB | 4.34 MiB/s, done.
Resolving deltas: 100% (322/322), completed with 127 local objects.
From https://github.com/BRL-CAD/gdal
 + f74cd4144...6133cf34a RELEASE    -> origin/RELEASE  (forced update)
 * [new tag]             v3.7.3     -> v3.7.3
 * [new tag]             v3.7.3RC1  -> v3.7.3RC1
Submodule path 'gdal/gdal': checked out '6133cf34a78077998406c0c4045bf51f06e3f49d'
user@linux:~/bext (main) $ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   gdal/gdal (new commits)

no changes added to commit (use "git add" and/or "git commit -a")
user@linux:~/bext (main) $ git add gdal/gdal
user@linux:~/bext (main) $ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   gdal/gdal

user@linux:~/bext (main) $ git commit -m "Update GDAL submodule reference"
[main 00ffbf0] Update GDAL submodule reference
 1 file changed, 1 insertion(+), 1 deletion(-)
user@linux:~/bext (main) $ git push
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 12 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 352 bytes | 352.00 KiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To github.com:BRL-CAD/bext.git
   23bb902..00ffbf0  main -> main
```

# Preparing a BRL-CAD copy of a dependency for addition as a new submodule

When adding a new submodule to bext, the first step is to prepare a BRL-CAD
fork (preferable) or repository (if forking isn't an option) of the project
that is going to be used.  We deliberately do not directly reference third
party repositories, to make sure our build can't be suddenly broken if one of
them disappears or radically changes.  Considerations when first forking:

* The ownership of the project should be the BRL-CAD organization.
* Uncheck the "clone only main branch" option - we want the full project
  history available to us if needed, including the various branches.  If
  the upstream disappears, the BRL-CAD copy may become the only copy.
* Once the fork is complete, verify that Github Actions are disabled for the
  fork - if not, go through and disable them.

Once we have a BRL-CAD/<dependency> repository, we can start looking at what
is needed to make it suitable for referencing by bext.  We almost never point
bext at the main branch of a project, or indeed any actively developed branch -
we want a stable, known target that we update deliberately once we have verified
things are working.  To this end, we create our own branch in the fork (typically
called RELEASE) and use that to do any necessary staging.

Note that normally (though not always) this doesn't involve modifying the
project source code - that is more typically handed by patch files in bext
itself to keep updating the parent project forks simpler.  What we usually need
to do in the upstream RELEASE branch is replace git submodules being used in
the parent project with full copies of the populated submodule directories.  In
other words, we want the RELEASE version of a repository to be a fully
self-contained clone without any dependencies on external repositories (the
boost repository is probably the most extreme example of this in bext, but
there are a number of others where we do the same thing.)  When the RELEASE
branch is updated for BRL-CAD, it is also necessary to fully update all of the
contents of these submodule replacements at the same time.  (More on how to do
this later.)

NOTE:  when considering a dependency for BRL-CAD usage, be sure to check not
only the license of the project itself but also all the licenses of its
dependencies.  Some projects will have optional features using libraries that
aren't license compatible with BRL-CAD, so those should be disabled and those
source codes not included in RELEASE.  If a project has a hard dependency on an
incompatible library, unless that dependency can be replaced or the need for it
removed we can't use the parent project.  (For example, we sometimes see new
academic codes associated with papers where the author relies on CGAL's GPL
licensed capabilities - even if the academic code itself is liberally licensed,
we would have to update or rewrite it to not require CGAL before we could use
it.

Once submodules and licenses have been handled and the project works in
isolation, the next step is to get it building as part of the bext ecosystem.
For initial experiments, you'll probably want to simply work with a copy of the
dependency rather than immediately integrating it as a submodule.   (If it
proves too difficult to work with and we have to scrap it, you'll want to avoid
the mess of also having to undo its addition as a submodule to bext.)  You'll
create a new top level directory for the dependency that will hold the
dependency file, patch files (if any are needed) and the actual project source
directory itself.  There are lots of examples to use as starting points, and
the patterns should be consistent.  The usual pain points of this part of the
process are:

  * You need to get the build to support using the *locally* built versions
    of dependencies, as well as the system versions.  If you have a system
    and a bext copy of a dependency present, you may find it's somewhat
    challenging to get the build system to focus on the version you want it
    to use.  zlib is particularly difficult, since it is quite common as
    a system dependency and it frequently "works" in builds without the dev
    spotting the problem.  We also must alter our zlib and png library names
    to avoid conflicts with system versions, so it is almost always necessary
    to update build systems to instruct them on how to find and use our
    copies.  Recommended best practice, in addition to testing on multiple
    platforms for building, is to use a freshly set up Ubuntu virtual machine
    with only the minimally required system development headers.

  * You may discover that the upstream project is using older versions of
    dependencies than BRL-CAD - in this situation, you'll want to do the work
    to update the code to use the newer dependency.  We typically won't bundle
    older versions - it's hard enough to stay current with just one! - and
    if you discover you need to make changes of that sort it is HIGHLY
    recommended to push those back to the upstream project so you can
    minimize your future maintenance overhead.

  * We prohibit dependencies from installing anything into the top level
    "root" directory - outputs should go into bin, lib, share and other
    standard subdirectories to conform with the layout of a BRL-CAD install.
    Occasionally this will require build system alterations - those sorts
    of tweaks are normally handled as patches, unless a particular situation
    suggests the upstream might be receptive to changing how their install
    structure is laid out.

Once you have everything installing into bext_output/install/ correctly and
using the correct dependencies, congratulations - you're now ready to add
the submodule to bext in lieu of a working source copy.  This will allow
bext to manage when and how the directory is populated based on build
settings, as well as providing a convenient(ish) mechanism for updating
submodule references as needed (see above).

As an example, we document below the steps taken for the geogram library from
https://github.com/BrunoLevy/geogram  After creating a full fork of the project
via github and verifying actions were not enabled, we clone the new repository
recursively to get the source code of all submodules:

```
$ git clone --recursive git@github.com:BRL-CAD/geogram.git
```

Once we have the geogram clone, we enter the directory and create our RELEASE
branch (since the upstream doesn't have such a branch, we don't have to worry
about a conflict - if that branch name becomes a problem in the future we can
adjust.)

```
$ cd geogram
geogram (main)$ git branch -c RELEASE
geogram (main)$ git checkout RELEASE
```

We can see geogram has a number of submodules:

```
geogram (RELEASE)$ git submodule
57a8140c8e9cb71d5f01824aa0e934bf71f34e9d src/lib/geogram/third_party/amgcl (1.4.3-13-g57a8140)
b4a91513317119ff71a1186906a052da0e535913 src/lib/geogram/third_party/libMeshb (RELEASE7.5-64-gb4a9151)
4296cc91b5c8c26d4e7d7aac0cee2b194ffc5800 src/lib/geogram/third_party/rply (v1.1.4-1-g4296cc9)
f8f805f04631323c8a75accc009eb9701f5ca027 src/lib/geogram_gfx/third_party/imgui (v1.89.7-docking-35-gf8f805f0)
3eaf1255b29fdf5c2895856c7be7d7185ef2b241 src/lib/third_party/glfw (3.3-781-g3eaf1255)
```

The first order of business is to convert those into committed source trees in
this repository.  Removing a submodule from git isn't as simple as removing the
directory itself - there are a couple specific commands that must be run.  Before
we do so, however, we want to make local copies of the contents of the submodules
we are going to clear so we can re-add them as standard file check-ins (see
https://stackoverflow.com/a/16162000):

```
geogram (RELEASE)$ mkdir ~/geogram_submodules
geogram (RELEASE)$ mv src/lib/geogram/third_party/amgcl ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/geogram/third_party/libMeshb ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/geogram/third_party/rply ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/geogram_gfx/third_party/imgui ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/third_party/glfw ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/geogram/third_party/amgcl ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/geogram/third_party/libMeshb ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/geogram/third_party/rply ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/geogram_gfx/third_party/imgui ~/geogram_submodules/
geogram (RELEASE)$ mv src/lib/third_party/glfw ~/geogram_submodules/
geogram (RELEASE)$ git submodule deinit -f src/lib/geogram/third_party/amgcl
Submodule 'src/lib/geogram/third_party/amgcl' (https://github.com/ddemidov/amgcl.git) unregistered for path 'src/lib/geogram/third_party/amgcl'
geogram (RELEASE)$ git submodule deinit -f src/lib/geogram/third_party/libMeshb
Submodule 'src/lib/geogram/third_party/libMeshb' (https://github.com/LoicMarechal/libMeshb.git) unregistered for path 'src/lib/geogram/third_party/libMeshb'
geogram (RELEASE)$ git submodule deinit -f src/lib/geogram/third_party/rply
Submodule 'src/lib/geogram/third_party/rply' (https://github.com/diegonehab/rply.git) unregistered for path 'src/lib/geogram/third_party/rply'
geogram (RELEASE)$ git submodule deinit -f src/lib/geogram_gfx/third_party/imgui 
Submodule 'src/lib/geogram_gfx/third_party/imgui' (https://github.com/ocornut/imgui.git) unregistered for path 'src/lib/geogram_gfx/third_party/imgui'
geogram (RELEASE)$ git submodule deinit -f src/lib/third_party/glfw
Submodule 'src/lib/third_party/glfw' (https://github.com/glfw/glfw.git) unregistered for path 'src/lib/third_party/glfw'
geogram (RELEASE)$ rm -rf .git/modules/src/lib/geogram/third_party/amgcl
geogram (RELEASE)$ rm -rf .git/modules/src/lib/geogram/third_party/libMeshb
geogram (RELEASE)$ rm -rf .git/modules/src/lib/geogram/third_party/rply
geogram (RELEASE)$ rm -rf .git/modules/src/lib/geogram_gfx/third_party/imgui
geogram (RELEASE)$ rm -rf .git/modules/src/lib/third_party/glfw
geogram (RELEASE)$ git rm --cached src/lib/geogram/third_party/amgcl
rm 'src/lib/geogram/third_party/amgcl'
geogram (RELEASE)$ git rm --cached src/lib/geogram/third_party/libMeshb
rm 'src/lib/geogram/third_party/libMeshb'
geogram (RELEASE)$ git rm --cached src/lib/geogram/third_party/rply
rm 'src/lib/geogram/third_party/rply'
geogram (RELEASE)$ git rm --cached src/lib/geogram_gfx/third_party/imgui
rm 'src/lib/geogram_gfx/third_party/imgui'
geogram (RELEASE)$ git rm --cached src/lib/third_party/glfw
rm 'src/lib/third_party/glfw'
geogram (RELEASE)$ git status
On branch RELEASE
Your branch is up to date with 'origin/main'.

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	deleted:    src/lib/geogram/third_party/amgcl
	deleted:    src/lib/geogram/third_party/libMeshb
	deleted:    src/lib/geogram/third_party/rply
	deleted:    src/lib/geogram_gfx/third_party/imgui
	deleted:    src/lib/third_party/glfw
geogram (RELEASE)$ git commit -m "Remove git submodules"
```

If we check, we now see that no submodules are reported:

```
geogram (RELEASE)$ git submodule
```

Next we restore the copies of the source code made earlier to the working tree:

```
geogram (RELEASE)$ mv ~/geogram_submodules/amgcl/\* src/lib/geogram/third_party/amgcl/
geogram (RELEASE)$ mv ~/geogram_submodules/libMeshb/\* src/lib/geogram/third_party/libMeshb/
geogram (RELEASE)$ mv ~/geogram_submodules/rply/\* src/lib/geogram/third_party/rply/
geogram (RELEASE)$ mv ~/geogram_submodules/imgui/\* src/lib/geogram_gfx/third_party/imgui/
geogram (RELEASE)$ mv ~/geogram_submodules/glfw/\* src/lib/third_party/glfw/
geogram (RELEASE)$ git status
On branch RELEASE
Your branch is ahead of 'origin/main' by 1 commit.
  (use "git push" to publish your local commits)

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	src/lib/geogram/third_party/amgcl/
	src/lib/geogram/third_party/libMeshb/
	src/lib/geogram/third_party/rply/
	src/lib/geogram_gfx/third_party/imgui/
	src/lib/third_party/glfw/
geogram (RELEASE)$ git add -A
geogram (RELEASE)$ git status
On branch RELEASE
Your branch is ahead of 'origin/main' by 1 commit.
  (use "git push" to publish your local commits)

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	new file:   src/lib/geogram/third_party/amgcl/CMakeLists.txt
	new file:   src/lib/geogram/third_party/amgcl/LICENSE.md
        <snip>
geogram (RELEASE)$ git commit -m "Commit files from former git submodules"
[RELEASE 27f3c3ccf] Commit files from former git submodules
 1061 files changed, 393698 insertions(+)
 create mode 100644 src/lib/geogram/third_party/amgcl/CMakeLists.txt
 <snip>
```

Once this step is complete, we have a "stand-alone" version of geogram and we push the
RELEASE branch back to github:

```
geogram (RELEASE)$ git push origin HEAD
Enumerating objects: 1231, done.
Counting objects: 100% (1231/1231), done.
Delta compression using up to 12 threads
Compressing objects: 100% (1195/1195), done.
Writing objects: 100% (1223/1223), 7.12 MiB | 8.99 MiB/s, done.
Total 1223 (delta 254), reused 23 (delta 1), pack-reused 0
remote: Resolving deltas: 100% (254/254), completed with 6 local objects.
remote: 
remote: Create a pull request for 'RELEASE' on GitHub by visiting:
remote:      https://github.com/BRL-CAD/geogram/pull/new/RELEASE
remote: 
To https://github.com/BRL-CAD/geogram.git
 * [new branch]          HEAD -> RELEASE
```

The RELEASE branch is now visible on the https://github.com/BRL-CAD/geogram project page.

Looking over the project contents, we see there are a number of third party components
we either don't want to or can't use.  HLBFGS and triangle.c are for noncommercial use
only, and must be removed.  Tetgen uses the AGPL and is incompatible with BRL-CAD's
licensing, so it too must be removed.

```
geogram (RELEASE)$ git rm -r src/lib/geogram/third_party/HLBFGS
geogram (RELEASE)$ git rm -r src/lib/geogram/third_party/triangle
geogram (RELEASE)$ git rm -r src/lib/geogram/third_party/tetgen
geogram (RELEASE)$ git commit -m "Remove sources for optional third party components with incompatible licenses"
[RELEASE 296fdc244] Remove sources for optional third party components with incompatible licenses
 21 files changed, 94593 deletions(-)
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/HLBFGS.cpp
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/HLBFGS.h
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/HLBFGS_BLAS.cpp
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/HLBFGS_BLAS.h
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/ICFS.cpp
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/ICFS.h
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/LineSearch.cpp
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/LineSearch.h
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/Lite_Sparse_Matrix.cpp
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/Lite_Sparse_Matrix.h
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/README.txt
 delete mode 100644 src/lib/geogram/third_party/HLBFGS/Sparse_Entry.h
 delete mode 100644 src/lib/geogram/third_party/tetgen/README.txt
 delete mode 100644 src/lib/geogram/third_party/tetgen/Tetgen1.6/README
 delete mode 100644 src/lib/geogram/third_party/tetgen/Tetgen1.6/tetgen.cpp
 delete mode 100644 src/lib/geogram/third_party/tetgen/Tetgen1.6/tetgen.h
 delete mode 100755 src/lib/geogram/third_party/tetgen/tetgen.cpp
 delete mode 100755 src/lib/geogram/third_party/tetgen/tetgen.h
 delete mode 100644 src/lib/geogram/third_party/triangle/README
 delete mode 100644 src/lib/geogram/third_party/triangle/triangle.c
 delete mode 100644 src/lib/geogram/third_party/triangle/triangle.h
geogram (RELEASE)$ git push origin HEAD
```

Next, we determine how to build the project without the components we either
don't want to or cannot use.  We will use build system options provided by the
upstream build if available - if alterations to the build logic are necessary
we will collect those into a patch file and use that .  This generally involves
turning off any extra features we don't want to simplify the build and
dependency requirements as much as possible.  In geogram's case, we tell it to
turn off graphics and build the library only, as well as disabling all the
optional third party components:

```
geogram (RELEASE)$ mkdir build && cd build
build (RELEASE)$ cmake ..  -DGEOGRAM_LIB_ONLY=ON -DGEOGRAM_WITH_GRAPHICS=OFF -DGEOGRAM_WITH_LUA=OFF -DGEOGRAM_WITH_HLBFGS=OFF -DGEOGRAM_WITH_TETGEN=OFF -DGEOGRAM_WITH_TRIANGLE=OFF
CMake Deprecation Warning at CMakeLists.txt:5 (cmake_minimum_required):
  Compatibility with CMake < 3.5 will be removed from a future version of
  CMake.

  Update the VERSION argument <min> value or use a ...<max> suffix to tell
  CMake that the project does not need compatibility with older versions.


-- The C compiler identification is GNU 12.2.1
-- The CXX compiler identification is GNU 12.2.1
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /usr/bin/cc - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: /usr/bin/c++ - skipped
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Doxygen >= 1.7.0 not found, cannot generate documentation
CMake Deprecation Warning at doc/CMakeLists.txt:7 (cmake_minimum_required):
  Compatibility with CMake < 3.5 will be removed from a future version of
  CMake.

  Update the VERSION argument <min> value or use a ...<max> suffix to tell
  CMake that the project does not need compatibility with older versions.


-- Configuring done (0.7s)
-- Generating done (0.1s)
-- Build files have been written to: /geogram/build
build (RELEASE)$ make
[  0%] Building C object src/lib/geogram/third_party/CMakeFiles/geogram_third_party.dir/libMeshb/sources/libmeshb7.c.o
[  0%] Building C object src/lib/geogram/third_party/CMakeFiles/geogram_third_party.dir/rply/rply.c.o
[  0%] Building C object src/lib/geogram/third_party/CMakeFiles/geogram_third_party.dir/zlib/adler32.c.o
[  0%] Building C object src/lib/geogram/third_party/CMakeFiles/geogram_third_party.dir/zlib/compress.c.o
[  1%] Building C object src/lib/geogram/third_party/CMakeFiles/geogram_third_party.dir/zlib/crc32.c.o
<snip>
```

One thing we spot when building starts is that there is a local zlib copy in geogram.  That's not necessarily
a problem if it does not cause a conflict (for example, we allow Qt to use its own zlib since that is much
simpler than trying to inject our version into their build and they isoloate their version) but it's something to
be aware of as a source of potential issues.  If it DOES cause a problem, we may have to alter geogram's build
to reference our zlib, if we are building a local copy.

After the library is complete, we use ldd to check and see if any system
libraries were linked that either already are or will need to be supplied by
bext are used:

```
geogram/build (RELEASE) $ ldd lib/libgeogram.so
	linux-vdso.so.1 (0x00007fff0db46000)
	libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007efc63200000)
	libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007efc63515000)
	libgomp.so.1 => /lib/x86_64-linux-gnu/libgomp.so.1 (0x00007efc63ef3000)
	libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007efc63ecf000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007efc62e00000)
	/lib64/ld-linux-x86-64.so.2 (0x00007efc63f6a000)
```

At least for Linux, all the linked libraries appear to be system libs and not dependencies we may need
to supply ourselves, which is good.  If geogram was going to require us to add more dependencies to avoid
the requirement to install system packages, we would have to repeat the above process for each of the
proposed dependencies as well before we would be ready to move on to bext.

Since we appear to have what we need, the next step takes place in the bext repository.
We create a new top level directory - in this case "geogram" - and add it to the toplevel
CMakeLists.txt file.

```
bext (main) $ mkdir geogram
bext (main) $ <manually edit CMakeLists.txt to add the following>
# Geogram - a programming library with geometric algorithms
# https://github.com/BrunoLevy/geogram
add_project(geogram GROUPS "BRLCAD_EXTRA")
```

We create a default "geogram.deps" file to list build dependencies for the bext superbuild.
By default everything depends on at least PATCH - if geogram ultimately needs other bext
components as well, they will be added later

```
bext (main) $ echo -e "PATCH\\n" > geogram/geogram.deps
```

Based on the above compilation, we know we will need to pass some geogram specific arguments
to configure.  Using one of the other CMakeLists.txt files as a template, we create the following
geogram/CMakeLists.txt file:

```
set(ENABLE_GEOGRAM "${ENABLE_GEOGRAM}" CACHE BOOL "Enable Geogram build")

if (ENABLE_GEOGRAM)

  git_submodule_init(geogram CMakeLists.txt)

  TargetDeps(GEOGRAM)

  ExternalProject_Add(GEOGRAM_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/geogram"
    BUILD_ALWAYS ${EXT_BUILD_ALWAYS} ${LOG_OPTS}
    #PATCH_COMMAND ${PATCH_EXECUTABLE};-E;-p1;${PATCH_OPTIONS};-i;${CMAKE_CURRENT_SOURCE_DIR}/geogram.patch
    CMAKE_ARGS
    ${BUILD_TYPE_SPECIFIER}
    -DBIN_DIR=${BIN_DIR}
    -DLIB_DIR=${LIB_DIR}
    -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_INSTALL_LIBDIR:PATH=${LIB_DIR}
    -DCMAKE_INSTALL_RPATH=${CMAKE_BUNDLE_INSTALL_PREFIX}/${LIB_DIR}
    -DGEOGRAM_LIB_ONLY=ON
    -DGEOGRAM_WITH_GRAPHICS=OFF
    -DGEOGRAM_WITH_LUA=OFF
    -DGEOGRAM_WITH_HLBFGS=OFF
    -DGEOGRAM_WITH_TETGEN=OFF
    -DGEOGRAM_WITH_TRIANGLE=OFF
    LOG_CONFIGURE ${EXT_BUILD_QUIET}
    LOG_BUILD ${EXT_BUILD_QUIET}
    LOG_INSTALL ${EXT_BUILD_QUIET}
    LOG_OUTPUT_ON_FAILURE ${EXT_BUILD_QUIET}
    STEP_TARGETS install
    )

  TargetInstallDeps(GEOGRAM GEOGRAM_DEPENDS)

  # Copy the license into position in CMAKE_BUNDLE_INSTALL_PREFIX
  file(MAKE_DIRECTORY ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other)
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/geogram/LICENSE
    ${CMAKE_BUNDLE_INSTALL_PREFIX}/doc/legal/other/geogram.txt
    COPYONLY
    )

endif (ENABLE_GEOGRAM)

# Local Variables:
# tab-width: 8
# mode: cmake
# indent-tabs-mode: t
# End:
# ex: shiftwidth=2 tabstop=8
```

By default the PATCH\_COMMAND line is commented out - at this stage we don't know if we need to
apply any patches or not.  We will definitely need to copy at least the LICENSE file.  In this
case we will probably also want to append some of the other third party licenses used by geogram
into it for completeness, so we may end up either scripting that or making our own custom file
to store in geogram/.   The latter is less ideal as it will have to be manually updated each time
we update geogram, but that might be simpler than a complex and fragile scripting solution - it
will require investigation.

The other item of note here is that we need find\_package to locate geogram.  By default CMake
does not bundle a module for this, and geogram is not one of the projects that uses the newer
project-provided CMake information convention for find\_package, so we will have to supply a
FindGeogram.cmake file.  In this case geogram itself has such a file in geogram/cmake/FindGeogram.cmake
so that is our starting point - we add it to the bext collection of CMake find\_package files:

```
bext (main) $ cp ~/geogram/cmake/FindGeogram.cmake CMake/
```

Although it is not immediately necessary for this stage of the setup, there is something we
should verify and correct about the FindGeogram.cmake file.  The bext setup requires that
find\_package respect \*\_ROOT variables to allow us to point search paths to our local copies
of libs rather than system versions, and it is common for more obscure cmake files to not
be set up to search in this fashion.  Accordingly, we alter FindGeogram.cmake
to add GEOGRAM\_ROOT to the set of search paths.  This will eventually be necessary for the
copy added to the main BRL-CAD build, as well as for any new dependencies that need to link
against the local copy of geogram in the future.

For the initial test, we comment out the git\_submodule\_init line and manually position a copy
of the geogram source tree in geogram/geogram to simulate a submodule clone.  For this test
we only are interested in building geogram and its requirements, rather than all of bext,
so we run make with the GEOGRAM_BLD target.

```
bext (main) $ cp -r ~/geogram geogram/
bext (main) $ mkdir build && cd build
build (main) $ cmake .. -DENABLE_ALL=ON
build (main) $ make GEOGRAM_BLD
[  0%] Creating directories for 'PATCH_BLD'
[  0%] No download step for 'PATCH_BLD'
[ 20%] No update step for 'PATCH_BLD'
[ 20%] No patch step for 'PATCH_BLD'
[ 20%] Performing configure step for 'PATCH_BLD'
-- PATCH_BLD configure command succeeded.  See also bext/build/patch/PATCH_BLD-prefix/src/PATCH_BLD-stamp/PATCH_BLD-configure-*.log
[ 40%] Performing build step for 'PATCH_BLD'
-- PATCH_BLD build command succeeded.  See also bext/build/patch/PATCH_BLD-prefix/src/PATCH_BLD-stamp/PATCH_BLD-build-*.log
[ 40%] Performing install step for 'PATCH_BLD'
-- PATCH_BLD install command succeeded.  See also bext/build/patch/PATCH_BLD-prefix/src/PATCH_BLD-stamp/PATCH_BLD-install-*.log
[ 40%] Built target PATCH_BLD-install
[ 60%] Creating directories for 'GEOGRAM_BLD'
[ 60%] Performing download step (DIR copy) for 'GEOGRAM_BLD'
[ 60%] No update step for 'GEOGRAM_BLD'
[ 80%] No patch step for 'GEOGRAM_BLD'
[ 80%] Performing configure step for 'GEOGRAM_BLD'
-- GEOGRAM_BLD configure command succeeded.  See also bext/build/geogram/GEOGRAM_BLD-prefix/src/GEOGRAM_BLD-stamp/GEOGRAM_BLD-configure-*.log
[ 80%] Performing build step for 'GEOGRAM_BLD'
-- GEOGRAM_BLD build command succeeded.  See also bext/build/geogram/GEOGRAM_BLD-prefix/src/GEOGRAM_BLD-stamp/GEOGRAM_BLD-build-*.log
[ 80%] Performing install step for 'GEOGRAM_BLD'
-- GEOGRAM_BLD install command succeeded.  See also bext/build/geogram/GEOGRAM_BLD-prefix/src/GEOGRAM_BLD-stamp/GEOGRAM_BLD-install-*.log
[ 80%] Built target GEOGRAM_BLD-install
[100%] Completed 'GEOGRAM_BLD'
[100%] Built target GEOGRAM_BLD
```

Once we have a successful completion, we inspect the contents of bext_output/install:

```
bext/build (main) $ ls -R ~/bext_output/install/
```

One thing to note is that a lot of the third party headers have been installed,
including lua (although we disabled it) and zlib.  It might be possible to trim
the installed set of headers down if the subset of geogram we are interested in
doesn't require all of them, but it would also require patching the build logic
so it's not a step to take without some motivation.  The zlib headers are concerning
if there's a risk of them getting incorporated into other builds instead of our
bundled zlib, but their location in include/geogram1/geogram/third_party/zlib should
help avoid accidental incorporation so for the moment we can wait and see. The
total file size for all the geogram headers is about 5M, which isn't enough to
justify a cleanup attempt without more pressing functional concerns.

Once everything looks like it should, we are ready to remove the working geogram
copy and add it properly as a submodule per the instructions at the top of this
file:

```
bext (main) $ rm -rf geogram/geogram && cd geogram
bext/geogram (main) $ git submodule add -b RELEASE https://github.com/BRL-CAD/geogram.git
bext/geogram (main) $ cd ..
bext (main) $ echo "        shallow = true" >> .gitmodules
bext (main) $ echo "        ignore = dirty" >> .gitmodules
```

Then add all the new and updated files to git for committing, and make the
commit - geogram will now be present as a dependency in bext.

```
bext (main) $ git add .gitmodules CMakeLists.txt CMake/ geogram/
bext (main) $ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   .gitmodules
	new file:   CMake/FindGeogram.cmake
	modified:   CMakeLists.txt
	new file:   geogram/CMakeLists.txt
	new file:   geogram/geogram
	new file:   geogram/geogram.deps
bext (main) $ git commit -m "Add geogram geometry library to bext"
[main 07d979f] Add geogram geometry library to bext
 6 files changed, 227 insertions(+)
 create mode 100644 CMake/FindGeogram.cmake
 create mode 100644 geogram/CMakeLists.txt
 create mode 160000 geogram/geogram
 create mode 100644 geogram/geogram.deps
bext (main) $ git push
```

The final "git push" step publishes the new addition to the public github bext
repository, and will also kick off a continuous integration test build on
Windows, Mac and Linux.  Because we tested only on Linux above, it is very
common to see build issues on one or both of Windows and Mac - any issues
should be immediately fixed, to keep bext building on all three platforms.
In the case of severe issues, comment out the add\_project line in the toplevel
bext CMakeLists.txt file corresponding to the new addition until the problems
can be resolved.

Having added the dependency successfully to bext, the next step is to set up
the main BRL-CAD build to make use of it and test out its incorporation into
a BRL-CAD bundle.  The bext build takes responsibility for making third party
dependencies relocatable by leveraging LIEF, but if the upstream project ends
up encoding fixed install paths rather than using relative lookups it may happen
that a working bext_output/install copy fails to work when copied into the main
BRL-CAD build.  If and when that happens, the original sources must be patched
to allow for relocatable execution (we have to do this for Tcl, for example.)
This should be done via patch file, and if the upstream project will take them
push the necessary changes upstream to simplify incorporating new versions down
the road.

Once the dependency is looking stable and useful, it's time to circle back and
test the build logic for various configurations - system verisons of
dependencies (if any), bundled versions of dependencies (if any), installing a
system version of geogram and verifying that the FindGeogram.cmake file
successfully detects it and our build logic disables the local build, and
checking that the BRL-CAD FindGeogram.cmake and build logic also work in both
configurations.  Unfortunately, especially given the huge number of projects
bext manages when everything is enabled, it's not practical to test all
combinations of system and local for all projects.  Generally speaking, the
most important configurations are ENABLE_ALL=ON, system detection on a
"vanilla" Linux box with just the minimal system development headers for X11
et. al., and system detection on a Linux box with a lot of system versions of
libraries present.  (For projects like geogram that have minimal entanglement
with other elements of bext it's more practical to check all configurations
using the GEOGRAM_BLD build target, but that won't always be possible -
build logic for projects like OSPray and Appleseed has the potential to
encounter a vast set of possible mixes of system and bundled libs.)

