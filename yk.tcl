#!/usr/bin/tclsh

# Consider translating it to dbus-tcl.

### Utility
### This is a simple version, does not handle properly!

set defaultwd $::env(HOME)

set qdbus_loc {qdbus qdbus-qt5}

set qdbus ""

foreach q $qdbus_loc {
	if {[auto_execok $q] != ""} {
		set qdbus $q
		break
	}
}

if {$qdbus == ""} {
	puts stderr "ERROR: qdbus not found among: $qdbus_loc. Please install."
	exit 1
}


proc pipe args {
	set __this_arg ""
	foreach __this_cmd $args {
		set __i_x [lsearch -all ${__this_cmd} {$-}]
		foreach __i_i ${__i_x} {
			lset __this_cmd ${__i_i} ${__this_arg}
		}
		#puts stderr "WILL EXEC: ${__this_cmd}"
		set __this_arg [uplevel ${__this_cmd}]
	}

	return ${__this_arg}
}

proc range args {
	set out ""
	if { [llength $args]%2 } {
		set args [list 0 {*}$args]
	}
	foreach {from to} $args {
		for {set i $from} {$i <= $to} {incr i} {
			lappend out $i
		}
	}

	return $out
}

proc y {args} {
	return [exec $::qdbus org.kde.yakuake {*}$args]
}

proc yl {object args} {
	return [split [y $object {*}$args] ,]
}

proc create_chain {pid fgpid} {
	# pid is the shell PID directly started by yakuake/konsole.
	# fgpid is the bottommost subprocess.
	if { $pid == $fgpid } {
		return
	}
	set current $fgpid
	while 1 {
			#puts stderr "Getting parent for the last pid of: $current"
		if { [catch {
			set parent [string trim [exec ps -o ppid= [lindex $current end]]]
		}] } {
			return $current ;# adopt the orphan
		}
		if { $parent == $pid } {
			return $current
		}
		lappend current $parent
	}
}

proc ysessions {} {
	# Grab the numbers of tabs that are valid.
	set tabno 0
	set sids ""
	while 1 {
		# Return empty session list in case when there was error.
		if { [catch {
			set sid [y /yakuake/tabs sessionAtTab $tabno]
		} ] } { return }

		#puts stderr "Tab $tabno SID $sid"
		if { $sid == -1 } break

		lappend sids $sid
		incr tabno
	}

	set tabs ""
	set activesess [y /yakuake/sessions activeSessionId]
	#puts stderr "Active session: $activesess"
	foreach sid $sids {
		set ksess "/Sessions/[expr $sid+1]"
		#puts stderr "SESSION: $ksess"
		if { [catch {
			set pid [y $ksess processId]
			set fgpid [y $ksess foregroundProcessId]
			set pidchain [create_chain $pid $fgpid]
		} ] } {
			return
		}
		if { $pidchain != "" } {
			#puts stderr "Getting command for the last pid of: $pidchain ($pid - $fgpid):"
			set cmdtostart [expr {
				[catch {exec ps -o command= [lindex $pidchain end]} cts]
					? "" : $cts }]
			#puts stderr "...: $cmdtostart"
		} else {
			set cmdtostart ""
		}
		# Take just the next command 
		set is_fg [expr {$pid == $fgpid }]
		set is_active [expr {$sid == $activesess}]
		if { [catch {set pxwd [pipe {exec pwdx $pid} {split $- :} {lindex $- 1} {string trim $-}]}] } {
			set pxwd $::defaultwd
		}
		if { [string index $pxwd 0] != "/" } {
			set pxwd ""
		}
		lappend tabs [subst {
			title "[y /yakuake/tabs tabTitle $sid]"
			active $is_active
			cwd "$pxwd"
			cmd [list $cmdtostart]
		} ]
			#debug-sessionid $sid
			#debug-pid $pid
			# ]
	}
	# blocked: debug-fgpid $fgpid

	return $tabs
}

proc yrestore {tabs} {

	set active_sid ""
	set tabid 0

	set cur_sids [yl /yakuake/sessions sessionIdList]
	set cur_tabs [llength $cur_sids]
	set ntabs [llength $tabs]

	# Make the same number of tabs as there were.
	while { $cur_tabs < $ntabs } {
		y /yakuake/sessions addSession
		incr cur_tabs
	}
	after 500

	# Now assign the sids in the same order
	set sids [lsort [yl /yakuake/sessions sessionIdList]]
	#puts stderr "SIDS: $sids"

	foreach tab $tabs sid $sids {
		# Get terminal id - we spawned just one, so it should be also one
		#puts stderr "Switch to: $sid"
		y /yakuake/sessions raiseSession $sid
		#puts stderr "Data:\n$tab"
		#after 1000
		#set tid [y /yakuake/sessions terminalIdsForSessionId $sid]

		if { [dict get $tab active] } {
			set active_sid $sid
		}

		# Title
		y /yakuake/tabs setTabTitle $sid "[dict get $tab title]"

		# Good, now change the working directory
		y /yakuake/sessions runCommand "cd [dict get $tab cwd]"

		# And run command
		# Watch if this command isn't a manually run command
		# to save the session!
		set cmd [dict get $tab cmd]
		if { [string first "yk.tcl -s" $cmd] != -1 } {
			set cmd "# Not running: $cmd"
		}
		y /yakuake/sessions runCommand $cmd
		incr tabid
	}

	if { $active_sid != "" } {
		y /yakuake/sessions raiseSession $active_sid
	}

}

switch -- [lindex $argv 0] {
	-l {
		set fd [open [lindex $argv 1] r]
		set con [read $fd]
		close $fd
		dict get [lindex $con 0] title
		yrestore $con
	}

	-s {
		set fname [lindex $argv 1]
		if { [file exists $fname] } {
			set bg 0
			while 1 {
				set abg [format "%03d" $bg]
				if { ![file exists $fname.$abg] } break
				#puts stderr "Exist $fname.$abg - trying next $bg"
				incr bg
			}
			file rename $fname $fname.$abg
		}
		set ystore [ysessions]
		if { [string trim $ystore] == "" } exit
		set fd [open $fname w]
		set sy $ystore
		puts -nonewline $fd $sy
		close $fd
		if { [info exists bg] } {
			# Check if the current file has the same contents
			# If so, the last file should be deleted.
			set fd [open $fname.$abg r]
			set sx [read $fd]
			close $fd
			if { $sx == $sy } {
				catch {file delete -force $fname.$abg}
			}
		}
	}

	default {
		puts "Usage: [file tail $argv0] \[-l|-s\] <session file>"
	}
}
