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
user@linux:~ $ git clone --recurse-submodules git@github.com:starseeker/bext.git
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

After this process, the bext repo should be updated with the procedure documented
earlier to update its reference to the gdal RELEASE HEAD:

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
To github.com:starseeker/bext.git
   23bb902..00ffbf0  main -> main
```

