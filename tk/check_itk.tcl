if {[llength $argv] != 1} {
    puts stderr "usage: check_itk.tcl minimum-version"
    exit 2
}

set minimumVersion [lindex $argv 0]
set packageHandler [package unknown]
if {$packageHandler eq ""} {
    puts stderr "Tcl has no package discovery handler"
    exit 1
}

# Ask Tcl to source package indexes, but do not execute Itk's ifneeded script;
# the latter loads Tk and consequently requires a display.
if {[catch {{*}$packageHandler Itk $minimumVersion} message]} {
    puts stderr "Unable to inspect system Itk packages: $message"
    exit 1
}

set requiredMajor [lindex [split $minimumVersion .] 0]
set selectedVersion ""
foreach version [package versions Itk] {
    if {[lindex [split $version .] 0] ne $requiredMajor ||
        [package vcompare $version $minimumVersion] < 0} {
        continue
    }
    if {$selectedVersion eq "" ||
        [package vcompare $version $selectedVersion] > 0} {
        set selectedVersion $version
    }
}

if {$selectedVersion eq ""} {
    puts stderr "Itk $minimumVersion or newer in major version $requiredMajor is required"
    exit 1
}

puts $selectedVersion

# Local Variables:
# mode: Tcl
# tab-width: 8
# End:
