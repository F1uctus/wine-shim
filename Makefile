# wine-shim — top-level Makefile
#
# Targets:
#   make                Build shim shared objects.
#   sudo make install   Install everything system-wide.
#   sudo make enable    Enable the runit service (idempotent).
#   sudo make setup     Run one-shot boot-time setup now.
#   sudo make uninstall Remove all installed files and disable service.

PREFIX     ?= /usr/local
BINDIR     ?= $(PREFIX)/bin
SBINDIR    ?= $(PREFIX)/sbin
LIBDIR     ?= $(PREFIX)/lib/wine-shim
SRCDIR     ?= $(PREFIX)/src/wine-shim
ETCDIR     ?= /etc/wine-shim
SVDIR      ?= /etc/sv/binfmt-wine-shim
RUNSVDIR   ?= /var/service

.PHONY: all install install-shims install-bin install-profiles install-sv \
        enable setup uninstall clean

all:
	$(MAKE) -C shims all

clean:
	$(MAKE) -C shims clean

install: install-shims install-bin install-profiles install-sv

install-shims: all
	$(MAKE) -C shims install DESTDIR=$(DESTDIR) PREFIX=$(PREFIX)
	install -d $(DESTDIR)$(SRCDIR)
	install -m 0644 shims/machine-id.c shims/Makefile $(DESTDIR)$(SRCDIR)/

install-bin:
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(SBINDIR)
	install -m 0755 bin/wine-shim-dmi-id  $(DESTDIR)$(BINDIR)/
	install -m 0755 bin/wine-shim-run     $(DESTDIR)$(BINDIR)/
	install -m 0755 bin/wine-shim-binfmt  $(DESTDIR)$(BINDIR)/
	install -m 0755 sbin/wine-shim-setup  $(DESTDIR)$(SBINDIR)/

install-profiles:
	install -d $(DESTDIR)$(ETCDIR)/profiles $(DESTDIR)$(ETCDIR)/machine-ids
	install -m 0644 profiles/default.profile $(DESTDIR)$(ETCDIR)/profiles/
	install -m 0644 profiles/iar.profile     $(DESTDIR)$(ETCDIR)/profiles/

install-sv:
	install -d $(DESTDIR)$(SVDIR)
	install -m 0755 sv/binfmt-wine-shim/run $(DESTDIR)$(SVDIR)/run

enable:
	@if [ ! -L $(RUNSVDIR)/binfmt-wine-shim ]; then \
	    ln -s $(SVDIR) $(RUNSVDIR)/binfmt-wine-shim; \
	    echo "Enabled runit service binfmt-wine-shim"; \
	else \
	    echo "Service already enabled"; \
	fi

setup:
	$(SBINDIR)/wine-shim-setup

uninstall:
	rm -f  $(RUNSVDIR)/binfmt-wine-shim
	rm -f  $(SVDIR)/run
	-rmdir $(SVDIR) 2>/dev/null
	rm -f  $(BINDIR)/wine-shim-dmi-id
	rm -f  $(BINDIR)/wine-shim-run
	rm -f  $(BINDIR)/wine-shim-binfmt
	rm -f  $(SBINDIR)/wine-shim-setup
	rm -f  $(LIBDIR)/libwine-shim-machine-id.so
	-rmdir $(LIBDIR) 2>/dev/null
	rm -f  $(SRCDIR)/machine-id.c $(SRCDIR)/Makefile
	-rmdir $(SRCDIR) 2>/dev/null
	@echo "Profiles in $(ETCDIR)/ left intact (remove manually if desired)."
