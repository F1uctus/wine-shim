# wine-shim default profile — plain Wine, no shims.
#
# Used for .exe files that don't match any other profile (e.g. running
# generic Windows tools via binfmt_misc without any customization).
#
# WINEPREFIX defaults to ~/.wine which is created on first wine(1) call.

export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
