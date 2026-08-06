#!/usr/bin/tclsh

if { $argv == "" } {
    puts stderr "Usage: [file tail $argv0] <command or file>"
    exit 1
}

if { "/" ni [split $argv ""] } {
	#puts stderr "DEBUG: running 'which' on '$argv' with catch"
    set err [catch {exec which $argv} path]
	#puts stderr "RESULT: $err"
	#puts stderr "OUTPUT: $path"
	if {$err} {
		# Check again if this is a local file
		set target [glob -nocomplain $argv]
		# But then, ignore the target whatsoever.
		# If it's nonempty, at least we know that [file type]
		# will not throw
		if {$target == ""} {
			puts stderr "ERROR: '$argv' is not recognized as a command nor local entry"
			exit 1
		} else {
			set path $argv
		}
	}
} else {
    set path $argv
}

set linkstack ""

while 1 {
    if { [file type $path] == "link" } {
        # Check first if already resolved.
        # If so, it means a recursive link.

        set resolved [file readlink $path]
        if { [file pathtype $resolved] != "absolute" } {
            set resolved [file join {*}[file dirname $path] $resolved]
        }
        if { $resolved in $linkstack } {
            puts stderr "Recursive link $resolved"
            exit 1
        }

        lappend linkstack $resolved
        puts -nonewline "$path -> $resolved"
        set path $resolved
		if { [glob -nocomplain $path] == "" } {
			puts " (missing)"
			exit 1
		}
		puts ""
        continue
    }

    puts $path
    break
}

