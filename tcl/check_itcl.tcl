if {[llength $argv] != 1} {
    puts stderr "usage: check_itcl.tcl minimum-version"
    exit 2
}

set minimumVersion [lindex $argv 0]
set packageHandler [package unknown]
if {$packageHandler eq ""} {
    puts stderr "Tcl has no package discovery handler"
    exit 1
}
if {[catch {{*}$packageHandler Itcl $minimumVersion} message]} {
    puts stderr "Unable to inspect system Itcl packages: $message"
    exit 1
}

set requiredMajor [lindex [split $minimumVersion .] 0]
set selectedVersion ""
foreach version [package versions Itcl] {
    if {[lindex [split $version .] 0] ne $requiredMajor ||
        [package vcompare $version $minimumVersion] < 0} {
        continue
    }
    if {$selectedVersion eq "" ||
        [package vcompare $version $selectedVersion] > 0} {
        set selectedVersion $version
    }
}

if {$selectedVersion eq "" ||
    [catch {package require -exact Itcl $selectedVersion} version]} {
    puts stderr "Itcl $minimumVersion or newer in major version $requiredMajor is required"
    exit 1
}

puts $version

# Local Variables:
# mode: Tcl
# tab-width: 8
# End:
