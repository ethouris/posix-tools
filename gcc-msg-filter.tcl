#!/usr/bin/tclsh

set pt_included {(In file included from) ([^:]+):([0-9]+)}
set pt_continued {^(\s*from) ([^:]+):([0-9]+)}
set pt_normal {^()([^:]+):([0-9]+):}

set heldup {}

while 1 {
    set n [gets stdin entry]
    if {$n == -1} break

    if { [regexp $pt_included $entry 0 title file line] || [regexp $pt_continued $entry 0 title file line] } {
        set entry "$file:$line: $title here"
    } elseif { ![regexp $pt_normal $entry 0 title file line ] } {
        lappend heldup $entry
        continue
    }

    if { $heldup != "" } {
        foreach l $heldup {
            append een "$file:$line: $l\n"
        }
        set entry $een$entry
        set heldup ""
    }

    puts $entry
}



