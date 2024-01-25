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

Once you have everything installing into bext_output/install/* correctly and
using the correct dependencies, congratulations - you're now ready to add
the submodule to bext in lieu of a working source copy.  This will allow
bext to manage when and how the directory is populated based on build
settings, as well as providing a convenient(ish) mechanism for updating
submodule references as needed (see above).

As an example, we document below the steps taken for the geogram library:
