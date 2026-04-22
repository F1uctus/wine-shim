/*
 * wine-shim: machine-id
 *
 * LD_PRELOAD shim that intercepts reads of /var/lib/dbus/machine-id (and
 * /etc/machine-id) and redirects them to a user-chosen replacement file.
 *
 * Wine's ntdll synthesises the SMBIOS Type-1 UUID from the D-Bus machine-id
 * when it cannot read /sys/class/dmi/id/product_uuid (which on Linux is
 * root-only by default). Licensing schemes that node-lock on SMBIOS UUID
 * (e.g. Sentinel RMS / IAR) therefore see Wine's fake UUID instead of the
 * host's real one. This shim lets us feed Wine any 16 raw bytes we choose.
 *
 * Controlling environment:
 *   WINE_SHIM_MACHINE_ID_FILE  Path to a file whose contents will be served
 *                              in place of /var/lib/dbus/machine-id and
 *                              /etc/machine-id. Must contain a 32-hex-char
 *                              machine-id (Wine tolerates either case,
 *                              dashes ignored).
 *
 * Build:  cc -O2 -fPIC -shared -Wl,-soname,libwine-shim-machine-id.so \
 *             -o libwine-shim-machine-id.so machine-id.c -ldl
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

static const char *TARGETS[] = {
    "/var/lib/dbus/machine-id",
    "/etc/machine-id",
    NULL,
};

static const char *fake_path(void) {
    const char *p = getenv("WINE_SHIM_MACHINE_ID_FILE");
    return (p && *p) ? p : NULL;
}

static int is_target(const char *p) {
    if (!p) return 0;
    for (const char **t = TARGETS; *t; ++t)
        if (strcmp(p, *t) == 0) return 1;
    return 0;
}

typedef int   (*openat_fn)(int, const char *, int, ...);
typedef int   (*open_fn)  (const char *, int, ...);
typedef FILE *(*fopen_fn) (const char *, const char *);

int openat(int dirfd, const char *path, int flags, ...) {
    mode_t m = 0;
    if (flags & (O_CREAT | O_TMPFILE)) {
        va_list ap; va_start(ap, flags); m = va_arg(ap, mode_t); va_end(ap);
    }
    openat_fn real = (openat_fn)dlsym(RTLD_NEXT, "openat");
    if (dirfd == AT_FDCWD && is_target(path)) {
        const char *p = fake_path();
        if (p) return real(AT_FDCWD, p, flags, m);
    }
    return real(dirfd, path, flags, m);
}

int open(const char *path, int flags, ...) {
    mode_t m = 0;
    if (flags & (O_CREAT | O_TMPFILE)) {
        va_list ap; va_start(ap, flags); m = va_arg(ap, mode_t); va_end(ap);
    }
    open_fn real = (open_fn)dlsym(RTLD_NEXT, "open");
    if (is_target(path)) {
        const char *p = fake_path();
        if (p) return real(p, flags, m);
    }
    return real(path, flags, m);
}

FILE *fopen(const char *path, const char *mode) {
    fopen_fn real = (fopen_fn)dlsym(RTLD_NEXT, "fopen");
    if (is_target(path)) {
        const char *p = fake_path();
        if (p) return real(p, mode);
    }
    return real(path, mode);
}
