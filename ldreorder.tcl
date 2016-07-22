#!/usr/bin/tclsh

package require Tcl 8.5
package require nm

proc logn text {
	puts -nonewline stderr $text
}

proc log text {
   logn $text\n
}   

proc main {argc argv} {

	while 1 {

		set cmdline [gets stdin]
		if { $cmdline == "" && [eof stdin] } {
			break
		}

		set p [lsearch -exact $argv -i]
		if { $p != -1 } {
			set ignoretypes [lindex $argv [expr {$p+1}]]
		} else {
			set ignoretypes wRt
		}

		# Fix the -option="some value with spaces" things
		set fixedcmdline ""
		set instr 0
		set stracc ""
		foreach x $cmdline {
			set p [string first \" $x]
			if { !$instr } {
				if { $p == -1 } {
					lappend fixedcmdline $p
					continue
				}

				log "CMDLINE: will fix unfinished argument: $x"

				# If inside the string, count how many you have inside.
				# Note that you don't have spaces here, so just check if
				# the number of rabbit ears is odd.

				set xps ""
				set xp $p
				while { $xp != -1 } {
					lappend xps $xp
					incr xp
					set xp [string first \" $x $xp]
				}

				set len [llength $xps]
				set odd [expr {$len & 1}]
				if { $len > 2 } {
					# There are some stupid "" inside - just get rid of all but the last opening
					if { $odd } {
						set frag [string range $x 0 [lindex $xps end]-1]
						set rest [string range $x [lindex $xps end] end]
						set x [string map {"\"" ""} $frag]$rest
						# update the position of the last opening ""
						set p [string first \" $x]
					} else {
						lappend fixedcmdline [string map {"\"" ""} $x]
						continue
					}
				}
				if { !$odd } {
					continue
				}

				# Now there should be just one open quote at the end
				set stracc "[string map {"\"" ""} $x] "
				set instr 1
				continue
			} else {
				log "CMDLINE: will append a fragment: $x"
				# Ok, now we got the next part of the string.
				# You can still have quotes inside, so take care.
				set p [string first \" $x]
				if { $p == -1 } {
					# Simple - just attach to the acc and take the next one.
					append stracc "$x "
					continue
				}

				set frag [string range $x 0 $p-1]
				set rest [string range $x $p+1 end]
				if { [string trim $rest] != "" } {
					# This won't be handled completely. Just blindly add this
					append frag [string map {"\"" ""} $rest
				}
				append stracc $frag
				lappend fixedcmdline "\"$stracc\""
				log "CMDLINE: fixed argument: '\"$stracc\"'"
				set instr 0
			}
		}

		lassign [parse-libraries $cmdline] dirs libs cmdline

		set libfiles ""
		foreach w $cmdline {
			if { ![string match -* $w] && [file exists $w] } {
				lappend libfiles $w
			}
		}

		if { $::tcl_platform(machine) == "x86_64" } {
			lappend dirs /lib64 /usr/lib64
		}
		lappend dirs /lib /usr/lib

		set cmdline [string map [list "\\\"" "\""] $cmdline]

		set libraries [find-libraries $dirs $libs]
		lappend libraries {*}$libfiles
		puts stderr "Libraries being considered:"
		puts stderr $libraries

		write stderr "Extracting symbols... "
		nm::extract_symbols $libraries
		puts stderr "\n... symbols from [array size nm::symbollist] libraries extracted:"
		if { [catch {set fd [open ldreorder.symbols w]}] } {
			set fd ""
		}
		foreach s [array names nm::symbollist] {
			puts stderr "$s: $nm::symbollist($s)"
			if { $fd != "" } {
				puts $fd "$s: $nm::symbollist($s)"
			}
		}
		if { $fd != "" } {
			close $fd
		}

		variable children
		variable parents
		write stderr "Finding dependencies by symbols... "
		foreach {library data} [array get nm::symbollist] {
			set orig_provider [file tail $library]
			set library [pure-library $library]
			log "Finding dependent of [file tail $library]: "
			if { ![info exists children($library)] } {
				set children($library) ""
			}
			foreach d $data {
				lassign $d mark symbol
				if { ![info exists nm::whererequired($symbol)] } {
					continue
				}
				if { $mark in [split $ignoretypes ""] } {
					# Don't treat these kind of symbols as a reason for dependency
					continue
				}

				foreach tar $nm::whererequired($symbol) {
					set target [pure-library $tar]
					#logn "($target?) "
					if { $target == $library } {
						#logn "no "
						# Yes, may happen if the library has linkage in itself, internally.
						# Of course, notify only alien connections, not internal ones.
						continue
					}
					# Check for internal errors
					#log "SYMBOL($mark/$symbol) DEFINED IN ([get nm::wheredefined($symbol)])"
					set wheredefined [lforeach s [get nm::wheredefined($symbol)] { return [pure-library [lindex $s 1]] }]
					if { $library ni $wheredefined } {
						#log " ** [file tail $library] SAID TO PROVIDE $mark/$symbol WHICH IS NOT TRUE - PROVIDERS ARE:"
						#log [lforeach l $wheredefined { return [file tail $l] }]
						continue
					}
					if { -1 == [lsearch $children($library) $target] } {
						lappend children($library) $target
						#log " -- DEPENDENT: $orig_provider <- $mark/$symbol <- [file tail $tar]"
					}
				}

				set children($library) [lsort -unique $children($library)]
				foreach ch $children($library) {
					if { $ch == $library } {
						log "Found '$ch' in children of itself!"
					}
					set parents($ch) [lsort -unique [concat [get parents($ch)] $library]]		
				}
			}
			log " --: [lforeach c $children($library) { return [file tail $c] }]"
		}
		puts stderr done.

		log "REQUESTER - PROVIDERS deps (children):"
		foreach {req prov} [array get children] {
			log "[file tail $req]: [lforeach lib $prov {return [file tail $lib]}]"
		}

		log "PROVIDER - REQUESTERS deps (parents):"
		foreach {child parent} [array get parents] {
			log "[file tail $child]: [lforeach p $parent {return [file tail $p]}]"
		}

		set ldcmdline [reorder-libraries $dirs $libs $libraries]
		set out "$cmdline $ldcmdline"
		puts $out
		catch {exec bash -c $out 2>@stderr >@stdout}
	}
}

proc generate-edges {library} {
	variable children
	logn "GENERATING EDGES([file tail $library]): "
	if { [get children($library)] == "" } {
		log "(nothing)"
		return ""
	}
	foreach c $children($library) {
		lappend out "$c $library"
		logn "[file tail $c] "
	}
	log ""

	return $out
}

proc reorder-libraries {dirs libs libraries} {

	set edges ""
	foreach l $libraries {
		set ee [generate-edges $l]
		set oo ""
		foreach e $ee {
			if { [lsearch -index 1 $edges [lindex $e 0]] != -1 } {
				logn "(dropping cycle: $e) "
				continue
			}
			lappend oo $e
		}

		puts "ADDING TO SORT: $oo"
		lappend edges {*}$oo
	}

	#set edges [concat {*}[lforeach l $libraries { return [generate-edges $l] }]]
	log "EDGES:\n[lforeach e $edges { lassign $e a b; return [list [file tail $a] [file tail $b]] }]"
	set edges [join $edges \n]
	set fail [catch {exec tsort 2>@stderr << $edges} sorted]
	log "SORTED: $sorted"
	set libraries [split $sorted \n]
	if { $fail } {
		# last line says "child process exited abnormally", which is not what we expect
		set libraries [lrange $libraries 0 end-1]
	}

	set sysdirs {/lib /lib64 /usr/lib /usr/lib64}
	set ldirs ""
	foreach d $dirs {
		if { $d in $sysdirs } {
			continue
		}
		lappend ldirs $d
	}

	set ldflags [lforeach d $ldirs {return -L$d}]
	set libtol {
		set tname [file tail $l]
		set lname [file rootname $tname]
		#puts "LIBNAME: $l --> $tname --> $lname"
		return -l[string range $lname 3 end]
	}
	lappend ldflags {*}[lforeach l $libraries $libtol]

	# Now add libraries that haven't been found between dependencies
	set libnames [lforeach l $libraries { return [file tail $l] }]
	foreach lib $libs {
		if { $lib ni $libnames } {
			if { [file extension $lib] ni {.so .a} } {
				set lib $lib.so
			}
			log "Adding $lib -- not found in dependent package"
			lappend ldflags [apply [list l $libtol] $lib]
		}
	}

	return $ldflags
}

proc pure-library {libname} {
	if { -1 == [string first :: $libname] } {
		return $libname
	}

	lassign [split $libname :] first
	return $first
}

proc lforeach {var list body} {
    set lambda [list $var $body]
    set result {}
    foreach item $list {
        lappend result [apply $lambda $item]
    }
    return $result
}


proc find-libraries {dirs libs} {
	# For every library name, try to find it among the directories
	# If not found, just report that it's not found, later it will
	# be put at the end, as likely to be system libraries that don't
	# have dependencies on libraries found here.
	puts stderr "Looking for libraries in dirs:\n[join $dirs \n]"

	set output ""

	foreach l $libs {
		set found no
		foreach d $dirs {
			set path [file join $d $l]
			if { [file exists $path.a] } {
				lappend output $path.a
				puts stderr "Library -l[string range $l 3 end]: $path.a"
				set found yes
				break
			} elseif { [file exists $path.so] } {
				lappend output $path.so
				puts stderr "Library -l[string range $l 3 end]: $path.so"
				set found yes
				break
			}
		}
		if { !$found } {
			puts stderr "Library not found: $l (.a or .so)"
		}
	}

	return $output
}

proc get var {
	upvar $var x
	if { [info exists x] } {
		return $x
	}
	return ""
}

proc parse-libraries {cmdline} {
	set dirs {}
	set libs {}
	set others {}
	puts "Parsing libraries:"
	foreach a $cmdline {
		switch -glob -- $a {
			-L* {
				set dir [string range $a 2 end]
				if { !([file exists $dir] && [file isdir $dir]) } {
					puts stderr "Note: directory does not exist: $a"
				} else {
					puts "... $a --> [file normalize $dir]"
					lappend dirs [file normalize $dir]
				}
			}

			-l* {
				set n lib[string range $a 2 end]
				puts "... $a --> $n"
				lappend libs $n
			}

			default {
				lappend others $a
				puts "... $a --> treating as file path or something else"
			}
		}
	}

	return [list $dirs $libs $others]
}

proc write {fd str} {
	puts -nonewline $fd $str
}


main $argc $argv
