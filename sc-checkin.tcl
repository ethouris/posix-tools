#!/usr/bin/tclsh

set file [lindex $argv 0]

if { ![file exists $file] } {
	puts stderr "File not found: $file"
	exit 1
}

set co "${file}@@CHECKEDOUT"

if { ![file exists $co] } {
	# File is not under version control.
	# Create the initial version.

	puts stderr "Not yet under version control - checking it as initial: ${file}@@0"

	file link $co $file
}

if { [file type $co] != "link" } {
	error "File '$co' is not a link - system messup!"
}

# Check if you have "LATEST". If not, create initial zero version.
set la ${file}@@LATEST

if { ![file exists $la] } {
	puts stderr "Creating version ${file}@@0"
	file copy $file ${file}@@0
	file link $la ${file}@@0
} else {
	puts stderr "Adding version next to [file readlink $la]"
	# Already exists - update
	# If it exists and is a symbolic link, it's a link to particular version.

	set linktar [file readlink $la]

	lassign [split $linktar @] name unu version

	if { $unu != "" && ![string is number $version] } {
		error "Invalid structure. $co should link to ${file}@@VERSION"
	}

	incr version
	file copy $file ${file}@@$version
	set perms [expr [file attributes $file -permissions] & 0555]
	file attributes $file -permissions $perms
	file delete $la
	file link $la ${file}@@$version
	exec chmod a-w ${file}@@$version
	# checkedout stays in current position
	puts stderr "Checked in as ${file}@@$version"
}





