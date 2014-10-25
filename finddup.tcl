#!/usr/bin/tclsh

proc dir_iterator {path} {
	set contents [glob -nocomplain $path/*]
	return [list 0 $contents]
}

proc dir_next {p_it} {
	upvar $p_it it
	lset it 0 [expr {[lindex $it 0] + 1}]
}

proc dir_is_end {it} {
	set fi [lindex $it 0]
	return [expr { [lindex [lindex $it 1] $fi] == "" } ]
}

proc dir_at {it} {
	return [lindex [lindex $it 1] [lindex $it 0]]
}

proc stack_push {st val} {
	upvar $st stack
	lappend stack $val
}

proc stack_size {st} { return [llength $st] }

proc stack_pop {st} {
	upvar $st stack
	if { [stack_size $stack] == 0 } {
		error "Popping empty stack!"
	}

	set val [lindex $stack end]
	set stack [lrange $stack 0 end-1]
	return $val
}

proc machine_init {path} {
	variable current
	variable state
	variable before

	set state NEXT
	set current [dir_iterator $path]
	set before {} ;# empty stack
}

proc restate { val } {
	set ::state $val
}

# Main machine executive
proc next_file {} {

	variable current
	variable state
	variable before

	#puts "Current: $current"
	#puts "State: $state"
	#puts "Before: $before"
	
	while 1 {
		switch $state {
			FILE {
				restate NEXT
				set path [dir_at $current]
				dir_next current

				return [list [file size $path] $path]
			}

			NEXT {
				if { [dir_is_end $current] } {
					restate END
				} else {
					set path [dir_at $current]
					if { [file isdirectory $path] } {
						restate DIR
					} else {
						restate FILE
					}
				}
			}

			DIR {
				stack_push before $current
				set current [dir_iterator [dir_at $current]]
				restate SUB
			}

			SUB {
				if { [dir_is_end $current] } {
					restate END
				} else {
					set path [dir_at $current]
					if { [file isdirectory $path] } {
						restate DIR
					} else {
						restate FILE
					}
				}
			}

			END {
				if { [stack_size $before] == 0 } {
					return { 0 "" }
				}

				set current [stack_pop before]
				dir_next current
				restate NEXT
			}
		}
	}
}

set arg [lindex $argv 0]

if { ![file isdirectory $arg] } {
	puts "$arg: not a directory"
	exit 1
}


machine_init $arg

array set map {}

while 1 {
	set sn [next_file]
	set size [lindex $sn 0]
	set name [lindex $sn 1]
	if { $name == "" } {
		break
	}

	lappend map($size) $name
}

foreach {size files} [array get map] {
	if { [llength $files] > 1 } {
		puts "$size: $files"
	}
}

