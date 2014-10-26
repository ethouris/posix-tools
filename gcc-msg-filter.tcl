#!/usr/bin/tclsh

set pt_included {(In file included from) ([^:]+):([0-9]+)}
set pt_continued {^(\s*from) ([^:]+):([0-9]+)}
set pt_normal {^()([^:]+):([0-9]+):}
set pt_fileonly {^()([^:]+):()}

set heldup {}

set file "<unspec>"
set line 0

while 1 {
    set n [gets stdin entry]
    if {$n == -1} break

	if { [regexp {^make\[[0-9]*\]:} $entry] } {
		puts $entry
		continue
	}

# 	puts stderr "+++DEBUG+++ $entry"

    if { [regexp $pt_included $entry 0 title file line] || [regexp $pt_continued $entry 0 title file line] } {
        set entry "$file:$line: $title here"
		set lastfl "$file:$line"
# 		puts stderr "+++DEBUG: entry changed to 'here'"
    } elseif { [regexp $pt_normal $entry 0 title file line ] } {
		set lastfl "$file:$line"
# 		puts stderr "+++DEBUG: entry unchanged: $title/$file/$line"
	} elseif { [regexp $pt_fileonly $entry 0 title file line] } {
		set lastfl "$file"
    } else {
        #lappend heldup $entry
		set lastfl "$file:$line"
# 		puts stderr "+++DEBUG: entry DROPPED"
        continue
	}


    if { $heldup != "" } {
# 		puts stderr "+++DEBUG: Heldup found: collecting all heldups in one entry list"
#		puts stderr "+++DEBUG: FOR LOCATION: $lastfl"
        foreach l $heldup {
            append een "$lastfl: $l\n"
# 			puts stderr "+++DEBUG: --> $l"
        }
        set entry $een$entry
        set heldup ""
    } else {
# 		puts stderr "+++DEBUG: No heldup"
	}

    puts $entry
}

    if { $heldup != "" } {
# 		puts stderr "+++DEBUG: Heldup @end found: collecting all heldups in one entry list:"
        foreach l $heldup {
            append een "$lastfl: $l\n"
# 			puts stderr "+++DEBUG: --> $l"
        }
        puts $een$entry
    } else {
# 		puts stderr "+++DEBUG: No heldup"
	}


