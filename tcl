#!/bin/bash

if [ "$1" == "" -o "$1" == "-h" -o "$1" == "--help" ]; then
echo >&2 "Usage:"
echo >&2 "	tcl [options] <command> <args>..."
echo >&2 "Options:"
echo >&2 "	-v <version>: force using tclsh<version>"
echo >&2 "	-p <packages>: add 'package require' with all <packages>"
exit 1
fi

VERSION=""
if [ "$1" == "-v" ]; then
	VERSION=$2
	shift
	shift
fi

PACKAGES=""
if [ "$1" == "-p" ]; then
	PACKAGES=$2
	shift
	shift
fi

OUTF=/tmp/tcldopipe$$.tcl
LEAVEPIPE=
if [ "$1" == "-t" ]; then
	OUTF=$2
	shift
	shift
	LEAVEPIPE=yes
fi

TCLPATH=`type -p tclsh$VERSION`

ARGS="$@"
>$OUTF

echo "#!$TCLPATH" >>$OUTF

if [ "$PACKAGES" != "" ]; then
	echo "foreach p {$PACKAGES} { package require \$p }" >>$OUTF
fi

#echo "puts {Executing command: $ARGS}" >>$OUTF
echo "set __result$$ [$ARGS]; if { [string trim \$__result$$] != \"\" } { puts \$__result$$ }" >>$OUTF
#echo "puts done." >>$OUTF

$TCLPATH $OUTF
if [ $LEAVEPIPE ]; then
	echo >&2 "($OUTF contains the intermediate pipe of the last command)"
else
	rm -rf $OUTF
fi

