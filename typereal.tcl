#!/usr/bin/tclsh

if { $argv == "" } {
    puts stderr "Usage: [file tail $argv0] <command or file>"
    exit 1
}

if { "/" ni [split $argv ""] } {
    set path [exec which $argv]
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
        puts "$path -> $resolved"
        set path $resolved
        continue
    }

    puts $path
    break
}

