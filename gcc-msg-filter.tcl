#!/usr/bin/tclsh

set pt_included {(In file included from) ([^:]+):([0-9]+)}
set pt_continued {^(\s*from) ([^:]+):([0-9]+)}
set pt_normal {^()([^:]+):([0-9]+):}
set pt_fileonly {^()([^:]+):()}
set pt_deprecated_phrase_regexp {is deprecated \(declared at}
set pt_deprecated_phrase_string {is deprecated (declared at}

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

#  	puts stderr "+++DEBUG+++ $entry"

# 	puts stderr "+++MATCH TO: $pt_deprecated_phrase_regexp"
	if { [regexp $pt_deprecated_phrase_regexp $entry] } {
		# Split the entry into two separate lines
		lassign [regexp -inline "$pt_normal\(.*$\)" $entry] 0 title file line follow
		set column ""
		if { [string is integer [string index $follow 0]] } {
			lassign [regexp -inline {([0-9]*):(.*)} $follow] 0 column follow
		}
		if { $column != "" } {
			set column :$column
		}
# 		puts stderr "+++ PHASE1: file=$file line=$line column=$column FOLLOWS: $follow"
		# Ok, this is impossible to be solved by regexp. Find the position of the key message.
		set msgpos [string first $pt_deprecated_phrase_string $follow]
		set iniwarn [string range $follow 0 $msgpos-1]
		set follow [string range $follow $msgpos+[string length $pt_deprecated_phrase_string] end]
# 		puts stderr "+++ PHASE2: iniwarn=$iniwarn follow=$follow"
		set parts [regexp -inline {([^:]+):([0-9]+)\)(.*)} $follow]
# 		puts stderr "+++PHASE3: MATCH '$follow': $parts"
		lassign $parts 0 dfile dline follow
		puts "$file:$line$column: ${iniwarn} is deprecated..."
		puts "$dfile:$dline: ... as declared here [string trim $follow]"
		continue
	} elseif { [regexp $pt_included $entry 0 title file line] || [regexp $pt_continued $entry 0 title file line] } {
        set entry "$file:$line: $title here"
		set lastfl "$file:$line"
#  		puts stderr "+++DEBUG: entry changed to 'here'"
    } elseif { [regexp $pt_normal $entry 0 title file line ] } {
		set lastfl "$file:$line"
#  		puts stderr "+++DEBUG: entry unchanged: $title/$file/$line"
	} elseif { [regexp $pt_fileonly $entry 0 title file line] } {
		set lastfl "$file"
    } else {
        #lappend heldup $entry
		set lastfl "$file:$line"
#  		puts stderr "+++DEBUG: entry DROPPED"
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


