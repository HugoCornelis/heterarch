dnl -*- autoconf -*-
dnl
dnl The neurospaces project : modeling tools for computational
dnl neuroscience.
dnl

dnl ##########################################################################
dnl 
dnl The neurospaces project
dnl 
dnl Copyright (C) 2007-2008 Hugo Cornelis
dnl 
dnl Hugo Cornelis, hugo.cornelis@gmail.com
dnl 
dnl ##########################################################################

# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)

# $Format: "AC_INIT(${package}, ${major}.${minor}.${micro}-${label}, ${email})"$
AC_INIT(${package}, 0.0.0-alpha, hugo.cornelis@gmail.com)



AC_MSG_CHECKING(whether we build universal binaries.)
AC_ARG_WITH(universal,
[AS_HELP_STRING([--with-universal],
              [Build universal binaries on Mac OS X.])],
[ case "$val" in
  no)

    AC_MSG_RESULT(no)
    OSX_UNIVERSAL="no"

    ;;
  *)

    AC_MSG_RESULT(yes)
    OSX_UNIVERSAL="yes"

    ;;
  esac ],
  AC_MSG_RESULT(no)
  OSX_UNIVERSAL="no"
)
AC_SUBST(OSX_UNIVERSAL)



AC_CONFIG_SRCDIR([Makefile.am])

dnl dnl all subdirs

dnl AC_CONFIG_SUBDIRS()

# $Format: "AM_INIT_AUTOMAKE(${package}, ${major}.${minor}.${micro}-${label})"$
AM_INIT_AUTOMAKE(${package}, 0.0.0-alpha)

PERL_MODULES=`(cd perl && find . -name "*.pm" | perl -pe 's/\n/ /g')`
AC_SUBST(PERL_MODULES)

PERL_DATA=`(cd perl && find . -name "numbers-7x11.txt" | perl -pe 's/\n/ /g')`
AC_SUBST(PERL_DATA)

# Checks for programs.

#   need to have this bail out when MTN = NULL
#   since it's required. 
AC_CHECK_PROGS([MTN],mtn monotone,[NULL])

#   check for packaging programs for debian and red hat.
#   no need to bail out if these are missing since they're optional. 
AC_CHECK_PROGS([DPKG_BUILDPACKAGE],dpkg-buildpackage,[NULL])
AC_CHECK_PROGS([DH],dh,[NULL])
AC_CHECK_PROGS([RPMBUILD],rpmbuild,[NULL])

dnl Check for Python and it's headers
AM_PATH_PYTHON(,[],[
   echo "Python is not installed."
   exit -1
])

AC_MSG_CHECKING([Python prefix is ])
  AC_MSG_RESULT(['$PYTHON_PREFIX'])

# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

# determine the test library to install

TEST_SPECIFICATION_FILES=`/bin/echo -n "tests/introduction.html " && find tests/specifications -name "*.t" | perl -pe 's/\n/ /g' && find tests/specifications/strings -name "*.txt" | perl -pe 's/\n/ /g' && find tests/data -name "*.yml" | perl -pe 's/\n/ /g'`
AC_SUBST(TEST_SPECIFICATION_FILES)


AC_CONFIG_FILES([Makefile])
dnl 		 perl/Makefile
dnl 		 python/Makefile])

AC_OUTPUT

