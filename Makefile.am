##
## The neurospaces project : modeling tools for computational
## neuroscience.
##

##############################################################################
##'
##' The neurospaces project
##'
##' Copyright (C) 2007-2008 Hugo Cornelis
##'
##' Hugo Cornelis, hugo.cornelis@gmail.com
##'
##############################################################################


SUBDIRS = \
	poetical \
	perl
#	python

# fill in the scripts that should go with the distribution:
dist_bin_SCRIPTS = \
	bin/heterarch-atomizer \
	bin/heterarch-build \
	bin/heterarch-check \
	bin/heterarch-create \
	bin/heterarch-dns-query \
	bin/heterarch-pull \
	bin/heterarch-push \
	bin/heterarch-rename \
	bin/heterarch-selector \
	bin/heterarch-snippet \
	bin/heterarch-sync \
	bin/heterarch-tagfilter \
	bin/heterarch-tagreplaceitems \
	bin/heterarch-version \
	bin/heterarch_cron

@PACKAGE@testdir=$(prefix)/neurospaces/$(PACKAGE)
nobase_dist_@PACKAGE@test_DATA=@TEST_SPECIFICATION_FILES@

RELEASE_MAJOR=`release-extract --major`
RELEASE_MINOR=`release-extract --minor`
RELEASE_MICRO=`release-extract --micro`

show-release-labels:
	echo "Release information (major-minor-micro): $(RELEASE_MAJOR)-$(RELEASE_MINOR)-$(RELEASE_MICRO)"

dist-keywords:
	release-expand $(PACKAGE) $(RELEASE_MAJOR) $(RELEASE_MINOR) $(RELEASE_MICRO) $(RELEASE_MAJOR).$(RELEASE_MINOR) hugo.cornelis@gmail.com --verbose

# the tests are copied overhere.
#
# The variable EXTRA_DIST could also be used here.

EXTRA_DIST = \
	docs \
	tests \
	license.txt

am__tar = ${AMTAR} chf - --format=posix "$$tardir"


clean-local: website-clean
	$(RM) -rf $(top_srcdir)/*/output/*
	$(RM) -f $(top_srcdir)/*/*.log
	$(RM) -rf $(top_srcdir)/*.deb
	$(RM) -f $(top_srcdir)/*.changes
	$(RM) -f $(top_srcdir)/*.dsc
	$(RM) -f $(top_srcdir)/build_*.log
	$(RM) -rf $(top_srcdir)/*_BUILD/
	$(RM) $(top_srcdir)/$(PACKAGE)-*.tar.gz

dist-hook: 
	$(srcdir)/install-sh -d $(distdir)/tests
	$(srcdir)/install-sh -d $(distdir)/tests/html
	( cd $(distdir)/tests && chmod -R u+w . && neurospaces_harness_2_html --introduction introduction.html )

#install-data-local: neurospaces_cpan_modules

#neurospaces_cpan_modules:
#	@echo "======================== Installing CPAN modules"
#	( cd cpan ; ./cpan_install *.gz )
#	touch $(top_srcdir)/neurospaces_cpan_modules

install-exec-local:
	( cd $(bindir) ; for script in `ls neurospaces-manager-gui | grep -v version | grep -v sync | grep -v pull | grep -v push` ; do ln -vsf {neurospaces-manager,heterarch}-`echo $$script | cut -f3- -d-` ; done )

uninstall-local:
	( cd $(bindir) ; echo heterarch-* ; $(RM) heterarch-* )

test: check

#TESTS = $(srcdir)/tests/neurospaces_harness

html-upload-prepare:
	rm -fr html/htdocs/neurospaces_project/$(PACKAGE)
	mkdir -p html/htdocs/neurospaces_project/$(PACKAGE)
# $Format: "	( cd tests && neurospaces_harness_2_html --header '<img src=\"ns-main-logo-dark2-notext-32x32.jpg\" alt=\"Main Neurospaces logo\"> ${package}, ${label}, ${email} <hr>' --introduction introduction.html )" $
	( cd tests && neurospaces_harness_2_html --header '<img src="ns-main-logo-dark2-notext-32x32.jpg" alt="Main Neurospaces logo"> neurospaces 0.1675 Thu, 27 Dec 2007 15:58:18 -0600 hugo<hr>' --introduction introduction.html )

#t perhaps also add a target to check the syntax of all the html ?

html-upload: html-upload-prepare
	scp -pr html/htdocs/* hcornelis,neurospaces@web.sourceforge.net:/home/groups/n/ne/neurospaces/htdocs/

website-clean:
	$(RM) -fr html/htdocs/neurospaces_project/heterarch/

website-prepare:
	heterarch-build --tags published

website-prepare-local:
	heterarch-build --tags local --tags published

website-upload: website-clean website-prepare html-upload

webcheck:
	rm -rf html/htdocs/neurospaces_project/heterarch/webcheck
	mkdir html/htdocs/neurospaces_project/heterarch/webcheck
	webcheck -o html/htdocs/neurospaces_project/heterarch/webcheck html/htdocs/neurospaces_project/heterarch --redirects=3

docs-level1:

docs-level2:

docs-level3: html-upload-prepare
	echo "Converted the regression tests to HTML"

docs-level4:

docs-level5:

docs-level6:

docs-level7:

docs: docs-level1 docs-level2 docs-level3 docs-level4 docs-level5 docs-level6 docs-level7

APP_NAME=neurospaces$(PACKAGE)

# the pkg-src target must create pkg/$(APP_NAME)-$(VERSION).tar.gz
pkg-src: dist
	mkdir -p pkg
	cp $(PACKAGE)-$(VERSION).tar.gz pkg/$(PACKAGE)-$(VERSION).tar.gz


# Create a deb package
pkg-deb: dist
	nspkg-deb $(PACKAGE) $(VERSION)

pkg-rpm: dist
	nspkg-rpm $(PACKAGE) $(VERSION)

pkg-osx: 
	nspkg-osx 
