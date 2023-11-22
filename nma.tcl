#!/usr/bin/tclsh

proc log args {
	puts stderr $args
}

if { ![info exists nm__use_as_library] } {
	set nm__use_as_library 0
}

namespace eval nm {
set args ""
set options ""
namespace export {args options}
}

if { $nm__use_as_library } {
	set nm::options {-raw -f -l}
} else {
	foreach a $argv {
		if { [string match -* $a] } {
			lappend nm::options $a
		} else {
			lappend nm::args $a
		}
	}

}

namespace eval nm {

set show_raw_names 0
if { "-raw" in $options } {
	set show_raw_names 1
}

set show_files 0
if { "-f" in $options } {
	set show_files 1
}

set show_requesters 0
if { "-l" in $options } {
	set show_requesters 1
}

set force_dynamic 0
if { "-d" in $options } {
	set force_dynamic 1
}

set analyze_sequential 0
if { "-s" in $options } {
	set analyze_sequential 1
}

set read_from_stdin 0
if { "-r" in $options } {
	set read_from_stdin 1
}


set out ""

set wheredefined() ""
set whererequired() ""

proc extract_symbols {libs} {

	# These will contain the output
	variable ::nm__use_as_library
	variable wheredefined
	variable whererequired
	variable symbollist
	variable show_raw_names
	variable show_requesters
	variable show_files
	variable force_dynamic
	variable analyze_sequential
	variable read_from_stdin

	# Check each lib first if it can be open for reading
	# and can be read normal symbols from

	set args ""
	set nmoutall ""

	if { !$read_from_stdin } {
		foreach lib $libs {
			if { ![file readable $lib] } {
				puts stderr "WARNING: $lib: not found, removing from arguments"
				continue
			}

			if { !$analyze_sequential } {
				puts stderr "PROBING LIBRARY: $lib"
			}
			set err [catch {exec nm $lib 2>@1} nmout]
			if { $analyze_sequential } {
				puts stderr "NOTE COMMAND: nm $lib"
			} else {
				if { $err != 0 } {
					puts stderr "ERROR: $nmout"
				} else {
					foreach line [split $nmout \n] {
						#puts stderr "OUTPUT: $line"
					}
				}
			}
			if { [string match "*no symbols*" $nmout] && "-D" ni $args } {
				if { !$force_dynamic || $analyze_sequential } {
					lappend args -D
				}

				if { $analyze_sequential } {
					set err [catch {execn nm -D $lib 2>@1} nmout]
					if { [string match "*no symbols*" $nmout] } {
						# Still no symbols? Skip library
						continue
					}
					puts stderr "NOTE COMMAND: nm -D $lib"
				}
			}

			if { $analyze_sequential } {
				append nmoutall $nmout\n
			} else {
				lappend args $lib
			}
		}

		if { !$analyze_sequential } {
			if { !$show_raw_names } {
				lappend args | c++filt
			}

			if { $force_dynamic } {
				set args "-D $args"
			}

			puts stderr "NOTE COMMAND: <nm $args>"
			set err [catch {exec nm {*}$args 2>@1} nmout]
		} else {
			set nmout $nmoutall
			puts stderr "NOTE: analyzing results..."
		}
	} else {
		set nmout [read stdin]
	}

	puts -nonewline stderr "NOTE: counting all lines for analysis... "
	set lns [exec wc -l << $nmout]
	if {$lns == 0} {
		puts stderr "WARNING: nm returned no symbols"
		return
	}
	puts stderr ""

	set objfile "o"
	set libfile [expr { [llength $libs] > 1 ? "" : "$libs:" }]
	set justset no
	set nln 0
	foreach ln [split $nmout \n] {
		incr nln
		puts -nonewline stderr "\r$nln/$lns ([expr {int(100.0*$nln/$lns)}]%)        "

		if { [string trim $ln] == "" } {
			set objfile ""
			if { $justset } {
				if { [string index $libfile end] != ":" } {
					append libfile :
				}
			}
			set justset no
			continue
		}

		set justset no

		if { [string match "*no symbols*" $ln] } continue

		if { [string match *: $ln] } {
			set justset yes
			set filename [string range $ln 0 end-1]
			#	&& [llength [file split $filename]] == 1
			if { [string match *o $filename]
			} {
				set objfile $filename
			} else {
				set libfile $filename
			}

			continue
		}

		if { [string index $libfile end] == ":" } {
			set filename "$libfile:$objfile"
		} elseif { $objfile != "" } {
			set filename $objfile
		} else {
			set filename $libfile
		}

		set eoa [eoa $ln]

		set adr [string range $ln 0 $eoa]
		set mark [string index $ln $eoa+2]
		set name [string range $ln $eoa+4 end]

		#puts stderr "LINE: $ln EOA=$eoa ADR=$adr MARK=$mark NAME=$name"

		if { $show_requesters && $mark == "U" } {
			# For undefined symbols, mark this as being requested inside this file (for a case of multiple files)
			lappend whererequired($name) $filename
		}

		if { [info exists wheredefined($name)] && [expr {[lsearch $wheredefined($name) [list $mark $filename]] != -1}] } {
			# Ignore; this is already found
		} else {
			lappend wheredefined($name) [list $mark $filename]
		}

		# Not used in interactive mode
		if { $nm__use_as_library } {
			if { $mark == "U" } {
				lappend undefined($filename) $name
			} else {
				lappend symbollist($filename) [list $mark $name]
			}
		}

# Unused?
# 	if { [lindex $adr 0] == "" } {
# 		set adr "--------"
# 	}
# 
# 	lappend out [list $adr $mark $name]

	}
}

proc eoa {line} {
	# This procedure counts end-of-address basing on what is in the line.
	# This procedure must be called for a line, which contains the symbol.

	set c0 [string index $line 0]
	if { $c0 == " " } {
		set cut [string trimleft $line]
		# The difference between trimmed and original is the number of spaces
		# This returns the position for 1-character symbol type marker
		# Go back 2 position to return the "end of address" sequence

		return [expr {[string length $line] - [string length $cut] - 2}]
	}
	
	if { [string is xdigit $c0] } {
		set pos [expr {[string first " " $line]-1}]
		if { $pos > 0 } { return $pos }
	}

	return 7
}

namespace export {
	extract_symbols
	wheredefined
	whererequired
	symbollist
}

if { !$::nm__use_as_library } {

	if { [llength $args] == 0 && "-r" ni $options} {
		puts stderr "Usage: [file tail $::argv0] \[-f|-l|-raw\] <files...>"
		puts stderr "\t-f - show the exact file where the symbol was defined (if it was)"
		puts stderr "\t-l - for every symbol show also files from where the symbol was requested"
		puts stderr "\t-raw - do not use c++filt to resolve mangled C++ symbols"
		puts stderr "\t-s - analyze every symbol file separately"
		puts stderr "\t-r - read output from nm command from standard input"
		exit 1
	}

	extract_symbols $args

# set output [join [lsort -index 1 $out] \n]

	set undefined ""
	set defined ""

	puts stderr "NOTE: displaying results (patience please if you use pager)"

	foreach {name data} [array get wheredefined] {
		if { $name == "" } continue

			if { !$show_raw_names } {
				if { $analyze_sequential } {
					# c++filt wasn't call before, if analyze_sequential is on. Call it now.
					set name [exec c++filt $name]
				}
				# Process some names that c++filt has problems with recognizing
				# c++filt recognizes destructors ending with D0 to D2, other numbers
				# are not recognized and so not demangled.
				# So, for example, xxxxD5Ev is changed into xxxxD0Ev.dttp.5, so that
				# it undergoes special processing in the next conditional
				if { [regexp {D([0-9])Ev$} $name unu number] } {
					if { $number > 2 } {
						set name [string range $name 0 end-4]D0Ev.dttp.$number
					}
				}

				# Another flavor of names with which c++filt has problems.
				# We have names like _Z*...prop1.10.prop2.20 - without this suffix
				# c++filt resolves it normally. In this case, cut off the suffix,
				# translate the name by c++filt, and add [prop1 10 prop2 20] to the name.
				if { [string match _Z* $name] && [string is integer [lindex [split $name .] end]] } {
					set last [lassign [split $name .] frontname]
					set frontname [exec c++filt $frontname]
					set name "$frontname \[$last\]"
				}
			}


		set isdef [lsearch -all -inline -not -index 0 $data U]
		if { $isdef == "" } {
			set entry "U:$name"
			if { $show_requesters && [info exists whererequired($name)] } { append entry "  ->  $whererequired($name)" }
			lappend undefined $entry
		} else {
			set mk [lindex [lindex $isdef 0] 0]
			if { [llength $data] != [llength $isdef] } {
				set mk $mk*
			}
			if { $show_files } {
				set fname ""
				foreach y $isdef {
					lappend fname [lindex $y 1]
				}
				set mk "$mk\([join $fname ,])"
				#set mk "$mk\($isdef\)"
			}
			set entry "$mk:$name"
			if { $show_requesters && [info exists whererequired($name)] } { append entry "  ->  $whererequired($name)" }
			lappend defined $entry
		}
	}

	puts [join [lsort $undefined] \n]
	puts [join [lsort $defined] \n]

}

}


