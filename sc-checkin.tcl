#!/usr/bin/tclsh

set file [lindex $argv 0]

if { ![file exists $file] } {
	puts stderr "File not found: $file"
	exit 1
}

set dirname [file dirname $file]

set verpath [file join $dirname .sc]

if { ![file exists $verpath] } {
	file mkdir $verpath
}

set co "${file}@@CHECKEDOUT"

if { ![file exists $verpath/$co] } {
	# File is not under version control.
	# Create the initial version.

	puts stderr "Not yet under version control - checking it as initial: ${file}@@0"

	file link $verpath/$co ../$file
}

if { [file type $verpath/$co] != "link" } {
	error "File '$verpath/$co' is not a link - system messup!"
}

# Check if you have "LATEST". If not, create initial zero version.
set la ${file}@@LATEST

if { ![file exists $verpath/$la] } {
	puts stderr "Creating version ${file}@@0"
	file copy $file $verpath/${file}@@0
	set perms [expr [file attributes $file -permissions] & 0555]
	file attributes $verpath/${file}@@0 -permissions $perms
	set wd [pwd]
	cd $verpath
	file link $la ${file}@@0
	cd $wd
} else {
	puts stderr "Adding version next to [file readlink $verpath/$la]"
	# Already exists - update
	# If it exists and is a symbolic link, it's a link to particular version.

	set linktar [file readlink $verpath/$la]

	lassign [split $linktar @] name unu version

	if { $unu != "" && ![string is number $version] } {
		error "Invalid structure. $verpath/$co should link to $verpath/${file}@@VERSION"
	}

	incr version
	file copy $file $verpath/${file}@@$version
	set perms [expr [file attributes $file -permissions] & 0555]
	file attributes $verpath/${file}@@$version -permissions $perms

	# Update LATEST link
	set wd [pwd]
	cd $verpath
	file delete $la
	file link $la ${file}@@$version
	exec chmod a-w ${file}@@$version
	cd $wd
	# checkedout stays in current position
	puts stderr "Checked in as $verpath/${file}@@$version"
}





