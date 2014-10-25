#!/usr/bin/tclsh8.5

#package require Tcl 8.5
package require tdom

proc showvar v {

	# block some variables

	if { $v in {auto_index auto_path errorInfo env tcl_platform} } {
		return "<blocked>"
	}

	upvar $v var

	if { ![info exists var] } {
		return
	}

	if { ![array exists var] } {
		return [set var]
	}


	foreach k [array names var] {
		lappend r "{($k)$var($k)} "
	}

	return $r
}

proc domAsTcl {dom} {
	set doc [$dom documentElement]

	set list [$doc asList]

	set result [domAsTclNode $list 0]
	
	set entlist ""

	foreach e $::entities {
		lappend entlist "#?ent $e"
	}

	puts stderr "Collected [llength $::entities] entities:\n$entlist"
	#puts stderr "EF:\n"
	#uplevel #0 {foreach e [info vars] { puts stderr "$e = [showvar $e]" } }

	return [join $entlist \n]\n\n$result
}

proc canBeRaw {text} {
	if { [catch {set no [llength $text]}] } {
		return no
	}

	# This is smart: will say "no" for "" and "one two", but not for "one"
	if { $no != 1 } {
		return no
	}

	if { [string index $text 0] == "-" || [string match {*[(){}/#;]*} $text] } {
		return no
	}

	if { [string trim $text] != $text } {
		return no
	}

	return yes
}

proc enclose {text} {
	if { [canBeRaw $text] } {
		return $text
	}

	if { [string first "\"" $text] != -1 } {
		return "\{$text\}"
	}

	set text [string map {\\ \\\\ \" \\\"} $text]

	return "\"$text\""
}

proc domAsTclNode {node indent} {
	# Process contents of the current node

	set ispaces [string repeat " " [expr {4*$indent}]]
	set ispace [string repeat " " 4]

	#lassign $node name attr subnodes
	foreach {name attr subnodes} $node break

# 	puts stderr "NODE: $name ATTR: $attr"

# 	if { [string index $name 0] == "#" } {
# 		switch [string range $name 1 end] {
# 			comment {
# 				return "\n$ispaces#$attr\n"
# 			}
# 
# 			text {
# 				return "-- \"$attr\"\n"
# 			}
# 		}
# 	}

	if { $name == "#comment" } {
		return "\n$ispaces#$attr\n"
	}

	set target $ispaces$name


# 	puts stderr "FIRST RESULT: $target"

	if { [catch {
	foreach {n v} $attr {
		append target " -$n [enclose $v]"
# 		puts stderr "RESULT STEP: $target"
	}
	} result] } {
# 		puts stderr "ERROR: attrs:\n$attr\n----------------\n$node\n-----------"
	}
# 	puts stderr "RESULT PARTIAL: $target"

	set node1 [lindex $subnodes 0]

	if { [lindex $node1 0] == "#text" } {
		append target " -- {\n$ispaces$ispace[lindex $node1 1]$ispaces}\n"
		set subnodes [lrange $subnodes 1 end]
	}


	if { [string trim $subnodes] != "" } {

		append target " \{\n"

		incr indent
		foreach n $subnodes {
			append target [domAsTclNode $n $indent]
		}

		append target "$ispaces\}\n\n"
	} else {
		#append target " \{\}\n"
		append target "\n"
	}

# 	puts stderr "RESULT: $target"

	return $target
}

proc slice str {
	set str [split $str " "]

	set result ""
	foreach s $str {
		set s [string trim $s]
		if { $s != "" } {
			lappend result $s
		}
	}

	return $result
}

proc requestEntityProvider {baseUri sysid pubid} {
	puts stderr "Requesting entity provider: $baseUri sysid:$sysid pubid:$pubid"

	set localid ""
	foreach k [array names ::supath] {
		if { [string match $k* $sysid] } {
			set len [string length $k]
			set suf [string range $sysid $len end]
			set localid "$::supath($k)$suf"
			break
		}
	}

	if { $localid == "" } {
		puts stderr " ... not found!"
		lappend ::entities [list $sysid "<not found!>"]
		return [list string $baseUri ""]
	}

	lappend ::entities [list $sysid [file normalize $localid]]

	#puts stderr "RQ:\n"
	#uplevel #0 {foreach e [info vars] { puts stderr "$e = [showvar $e]" } }

	set fd [open $localid r]
	set contents [read $fd]
	close $fd

	# Good - and now let's fake it. Clear the entity definitions, providing your own.

	set fake ""

	foreach line [split $contents \n] {
		set splot [slice $line]
		set ent [lindex $splot 0]
		set name [lindex $splot 1]
		if { $ent != "<!ENTITY" } {
			lappend fake $line
			continue
		}
		lappend fake "$ent $name \"\$\{$name\}\">"
	}

	set contents [join $fake \n]
	
	#puts stderr $contents

	return [list string $baseUri $contents]
}

set filename [lindex $argv 0]
set argv [lrange $argv 1 end]

# Defaulted
set option(type) ""

foreach e $argv {
    if { [string match *=* $e] } {
        lassign [split $e =] match subst
        set ::supath($match) $subst
        continue
    }

    if { [string match -*/* $e] } {
        lassign [split [string range $e 1 end] /] optname value
        set ::option($optname) $value
        continue
    }
}

set fd [open $filename r]
puts stderr "Processing $filename"

set entities ""
set typestr ""
set sourcearg "-channel $fd"
if { $option(type) != "" } {
    set sourcearg [list [read $fd]]  ;# [list] required against {*}
    if { $option(type) == "html" } {
        set typestr "-html"
    } elseif { $option(type) == "simple" } {
        set typestr "-simple"
    } else {
        puts stderr "Unknown -type/$option(type): use -type/simple or -type/html"
        exit 1
    }
}

set xml [dom parse -externalentitycommand requestEntityProvider {*}$sourcearg {*}$typestr]
close $fd

puts "#?tml: TUL\n"
puts "#?xml: version=\"1.0\" encoding=\"UTF-8\""
puts "# (generated by xml-as-tcl)\n"


puts [domAsTcl $xml]
puts "# vim:ft=tcl"
