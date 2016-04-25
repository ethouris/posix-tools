Posix tools
===========

#### carve

Same as 'cut', but it can also take negative ranges to count from the end. It works only for words separated by spaces.

E.g.: `echo statement | carve 1--4` results in `state`.

#### finddup.tcl

Find duplicates of files (same size is checked first, then also contents).

#### gcc-msg-filter.tcl

This interprets messages from gcc and changes the way how errors are reported from a cascade of includes.
The gcc reports in the following form:

    In file included from file1.h:2
     from file2.h:3
     from file3.h:5
    file.cc:10: error: <error message>

This changes it into something that editors can interpret and make it jump into appropriate #include location:

    file1.h:2: In file included from here
    file2.h:3: from here
    file3.h:5: from here
    file.cc:10: error: <error message>

#### ldd3

The "ldd tree" tool. It shows the dynamic libraries required by the executable in a form of tree.
This is useful if you can see one library being included unexpectedly in two different versions
and you want to know, which of the dependent libraries has included another dependent library,
which was requesting incorrectly this library.

#### ldreorder.tcl

Takes a link command for gcc and interprets all occurrences of static libraries. These libraries
are then analyzed as to which is using which's symbols and then libraries are reordered so that
they can be linked without linker errors.

Linker errors occur, when the symbol provider precedes symbol requirer. Happens only for static
libraries. 

#### lns

Just like `ln -s`, but it works correcly with the relative paths in arguments and alwys
creates the link target as relative.

#### nm-unified

Reads multiple `*.o` files from the arguments, does `nm` on each of that and outputs everything
just as if all `*.o` files were contents of an archive with path `/.a`. This may be needed sometimes
for `nma.tcl` to help it properly interpret the `nm` output.

#### nma.tcl

An `nm` on steroids: it reads multiple object or library files, extracts the symbols from them,
and tries to match them to each other, then displays it possibly with additional information.
Symbols that were completely undefined and not resolved by any other part of the library are
displayed first as undefined. Normally it displays only the symbol and the nm flag for it,
with -f it also displays the files that provides the symbol. The format is:

Minimum:

    X:SYMBOLNAME

Maximum:

	X*(PROVIDER):SYMBOLNAME -> REQUESTER

Where:
* initial X is the one-letter flag for this symbol as provided by `nm` (see `man nm` for explanation)
* If followed by `*`, it means that the symbol is both provided and required by the provider
* Optional `(PROVIDER)` is added with -f option, it's the list of filenames that provide this symbol
* `SYMBOLNAME` is the name of the symbol, filtered by c++filt (use -raw option to prevent it)
* Optional `-> REQUESTER` shows the libraries where this symbol occurred as undefined and it was matched with it (available with -l option)

#### pkg-config-install

A replacement for pkg-config, does the same as pkg-config, unless the packet isn't installed, in
which case it tries to install it using `pkg-install` (see below).

#### pkg-find-mapping

Tries to find a mapping that can resolve the package provider for given package.

#### pkg-install

Tries to install a package by the name provided by pkg-config. The package is considered provided,
if pkg-config says so. If not (lacking *.pc file), then it tries to find *.pd file that would contain
information about how to make this package installed. It tries also to get information about how
to install the packet from `pkg-find-mapping`.

#### run-winapp

This is for Cygwin only. It recognizes the command line that should point to a Cygwin path and
runs given application with arguments where Cygwin path has been translated into Windows path.

#### sc-checkin.tcl

This is a very simple, primitive, current-dir-only kind-of version control tool. It uses path
syntax similar to ClearCase: uses `@@` added to the filename

#### tarx

A wrapper for `tar x`, which recognizes the compress program from the archive filename suffix.

#### tcl

A command that executes and prints the results of a Tcl command, using tclsh interpreter.

#### tclml

An interpreter of a simple markup language using Tcl command syntax.

#### trename

A Tk wrapper for rename functionality. Requires one argument, the name of the file to be renamed.
It opens a simple editor to edit the target filename.

#### typereal.tcl

Resolves symbolic links recursively and shows the complete path from the given link to a
real filename, which is the ultimate target of the link connections.

#### uname-a

Extracts all possible options from `uname` command, then displays the use of `uname` with every
possible option.

#### xml-as-tcl.tcl

Translates XML file into a simplified Tcl list syntax.

#### yk.tcl

Utility for `yakuake`, which reads the current configuration. It was used to restore the previous
`yakuake` session. Now it doesn't work automatically (that is, from cron, for
example) due to unavailable dcop connection information, however still works when run
manually from command line.

#### ysess-store

Helper for `yk.tcl`, tries to grab the information about the current `yakuake` session.

