# wine-shim iar profile — IAR Embedded Workbench CLI tools.
#
# Loads the machine-id shim so Wine's SMBIOS synthesis produces raw UUID
# bytes matching the host's real BIOS, which is required by IAR's Sentinel
# RMS PC-locked licence.
#
# Prerequisites (run once, or via /usr/local/sbin/wine-shim-setup):
#   * /etc/wine-shim/machine-ids/host-dmi populated from the host DMI UUID
#   * ~/.wine-iar created with wineboot and vcrun2019 (mfc140u.dll etc.)
#   * Inside the prefix, symlinks to the real IAR install:
#       drive_c/Program Files/IAR Systems       -> <path>/Program Files/IAR Systems
#       drive_c/ProgramData/IARSystems          -> <path>/ProgramData/IARSystems
#       drive_c/users/<user>/AppData/Local/IAR Embedded Workbench
#                                               -> <path>/Users/<user>/AppData/Local/IAR Embedded Workbench

export WINEPREFIX="$HOME/.wine-iar"
export WINEARCH=win64
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"

export WINE_SHIM_LIBS="machine-id"
export WINE_SHIM_MACHINE_ID_FILE="${WINE_SHIM_MACHINE_ID_FILE:-/etc/wine-shim/machine-ids/host-dmi}"
