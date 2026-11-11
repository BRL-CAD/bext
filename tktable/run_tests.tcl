# Test the installed package so missing runtime files fail before the suite runs.
lassign $argv packageDir testDir
set argv {}
set auto_path [linsert $auto_path 0 $packageDir]
package require Tk
package require -exact Tktable 2.12.2
package require tcltest
::tcltest::configure -testdir $testDir -singleproc 1
# Keep Tk's tcltest cleanup from exiting before we can return the test status.
::tcltest::testConstraint interactive 1
set failed [::tcltest::runAllTests]
destroy .
exit $failed
