if {[llength $argv] != 1} {
    puts stderr "usage: check_itcl.tcl minimum-version"
    exit 2
}

set minimumVersion [lindex $argv 0]
if {[catch {package require Itcl $minimumVersion} version]} {
    puts stderr "Itcl $minimumVersion or newer is required: $version"
    exit 1
}

puts $version

# Local Variables:
# mode: Tcl
# tab-width: 8
# End:
