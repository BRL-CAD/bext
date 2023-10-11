# bext - Notes

When using submodules, there are some fairnly non-intuitive aspects of managing them that need to be taken into consideration:

# Adding a submodule (using Tcl as an example)
```
user@linux:~/bext (main) $ cd tcl
user@linux:~/bext/tcl (main) $ git submodule add -b RELEASE https://github.com/BRL-CAD/tcl.git
```
Edit the new .gitmodules entry to add the "shallow = true" and "ignore = dirty" lines, git add the updated .gitmodules file, and commit the addition of the new submodule.


# Finding the currently referenced submodule SHA1

Git stores a SHA1 to the upstream commit it will target, but this SHA1 isn't readily visible in the working git clone's files.  To see it, use git ls-tree - for example, this prints the current Tcl SHA1:
```
user@linux:~/bext (main) $ git ls-tree main tcl/tcl
160000 commit 338c6692672696a76b6cb4073820426406c6f3f9	tcl/tcl
```

# Updating a submodule to a newer upstream

TODO

# Removing a submodule

As summarized by https://gist.github.com/myusuf3/7f645819ded92bda6677 (using tcl/tcl as an example):

* Delete the .gitmodules entry for the submodule being removed
* git add .gitmodules
* Delete the .git/config entry for the submodule being removed
* git rm --cached tcl/tcl
* rm -rf .git/modules/tcl/tcl
* git commit -m "Removing Tcl submodule"
* rm -rf tcl/tcl

