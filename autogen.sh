#!/bin/sh
# Run this to generate all the initial makefiles, etc.

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

PKG_NAME="Genius"

(test -f $srcdir/configure.in \
  && test -d $srcdir/src \
  && test -f $srcdir/src/calc.h) || {
    echo -n "**Error**: Directory "\`$srcdir\'" does not look like the"
    echo " top-level Genius directory"
    exit 1
}

. $srcdir/macros/autogen.sh