# wine-shim/shims — LD_PRELOAD shared-object shims
#
# Each .c file produces one libwine-shim-<name>.so.
# To add a new shim: drop foo.c here, add `foo` to SHIMS, run `make && sudo make install`.

PREFIX   ?= /usr/local
LIBDIR   ?= $(PREFIX)/lib/wine-shim

SHIMS    := machine-id

CC       ?= cc
CFLAGS   ?= -O2 -Wall -Wextra -fPIC
LDFLAGS  ?=
LIBS     := -ldl

TARGETS  := $(SHIMS:%=libwine-shim-%.so)

all: $(TARGETS)

libwine-shim-%.so: %.c
	$(CC) $(CFLAGS) -shared -Wl,-soname,$@ -o $@ $< $(LDFLAGS) $(LIBS)

install: all
	install -d $(DESTDIR)$(LIBDIR)
	install -m 0755 $(TARGETS) $(DESTDIR)$(LIBDIR)/

clean:
	rm -f $(TARGETS)

.PHONY: all install clean
