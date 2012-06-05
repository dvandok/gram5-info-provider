#  File: gram5-info-provider/Makefile
#  Author: Dennis van Dok <dennisvd@nikhef.nl>
#
#  Copyright 2012  Stichting FOM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# This package is pretty trivial to set up and install.
# There is no source code to compile; it only contains
# a couple of scripts.
# This Makefile respects the $DESTDIR convention that
# is commonly used in the GNU build system.

# the relevant variables
prefix = /usr
datadir = $(prefix)/share
sbindir = $(prefix)/sbin
plugindir = $(prefix)/libexec # not FHS compliant, but Red Hat uses it

DESTDIR =

# These variables should not be changed by the user

package = gram5-info-provider
version = 0.2
scripts = update-gram-info-provider.pl \
	update-gram-glue2-computingservice-static.pl \
	update-gram-glue2-endpoint-static.pl \
	update-gram-glue2-manager-static.pl \
	update-gram-glue2-share-static.pl \
	update-gram-glue2-tostorageservice-static.pl

gipdynamicplugins = globus-gip-gram5-glue2-endpoint-dynamic.pl

distfiles = Makefile LICENSE gram5-info-provider.spec $(scripts) $(gipdynamicplugins)

.PHONY: install build installdirs install-scripts install-plugins

build:
	@echo "build done. Run 'make install' to finish the installation"

installdirs:
	mkdir -p $(DESTDIR)/$(sbindir)
	mkdir -p $(DESTDIR)/$(datadir)
	mkdir -p $(DESTDIR)/$(plugindir)

# Install scripts and plugins without their filename extension.
install-scripts: installdirs
	for i in $(scripts) ; do \
	    install -m 755 $$i $(DESTDIR)/$(sbindir)/`echo $$i | sed 's/\..*//'` ; \
	done

install-plugins: installdirs
	for i in $(gipdynamicplugins) ; do \
	    install -m 755 $$i $(DESTDIR)/$(plugindir)/`echo $$i | sed 's/\..*//'` ; \
	done

install: install-scripts install-plugins

dist:
	rm -rf _dist/
	mkdir -p _dist/$(package)-$(version)
	install -m 644 $(distfiles) _dist/$(package)-$(version)
	tar cCfz _dist $(package)-$(version).tar.gz $(package)-$(version)
