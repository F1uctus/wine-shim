# wine-shim

Run hardware-locked Windows CLI tools on Linux via Wine — with correct SMBIOS
identity, per-application profiles, and transparent `binfmt_misc` dispatch.

Built specifically to make **IAR Embedded Workbench** CLI tools (`iarbuild`,
`iccarm`, `ilinkarm`, …) work from a dual-booted Windows installation, but the
profile system is generic and supports any Windows program that needs Wine
environment customization.

## Problem

Wine synthesizes the SMBIOS Type-1 UUID from `/var/lib/dbus/machine-id`
instead of reading the host's real DMI UUID (which is root-only on Linux).
Programs that node-lock their license to the SMBIOS UUID — such as IAR's
**Sentinel RMS** — see a different fingerprint under Wine than on native
Windows and refuse to run.

Additionally, Wine's `ntdll/unix/system.c:get_system_uuid()` copies the
machine-id bytes straight into the SMBIOS structure **without** the
first-three-field byte reversal that real Windows BIOS firmware applies.
Even if you write the correct UUID string into the machine-id file, the
raw SMBIOS bytes (which is what Sentinel actually hashes) will differ.

## Solution

1. **`machine-id` shim** — an `LD_PRELOAD` shared object that intercepts
   `open`/`openat`/`fopen` of `/var/lib/dbus/machine-id` (and
   `/etc/machine-id`) and redirects them to a user-chosen file containing
   a pre-compensated machine-id.

2. **`wine-shim-dmi-id`** — reads the host's real SMBIOS UUID and applies
   the compensating byte-pair reversal on the first three UUID fields, so
   that after Wine's naive copy the raw SMBIOS bytes match a real Windows
   system exactly.

3. **Profile system** — POSIX-sourced config files in `/etc/wine-shim/profiles/`
   (or `~/.config/wine-shim/profiles/`) that set `WINEPREFIX`, `WINEARCH`,
   shim selection, and any other Wine environment per application.

4. **`binfmt_misc` dispatcher** — registers the PE `MZ` magic so you can run
   `.exe` files directly. A `.wineshim` marker file anywhere in the directory
   ancestry selects the profile.

5. **runit service** — re-runs the setup at every boot so the machine-id cache
   and binfmt_misc registration survive reboots.

## Repository layout

```
wine-shim/
├── Makefile                    Top-level build + install
├── shims/
│   ├── Makefile                Shim build rules
│   └── machine-id.c           LD_PRELOAD machine-id redirector
├── bin/
│   ├── wine-shim-dmi-id       UUID → pre-swapped machine-id converter
│   ├── wine-shim-run          Profile-based Wine launcher
│   └── wine-shim-binfmt       binfmt_misc entry point
├── sbin/
│   └── wine-shim-setup        Boot-time setup (root, idempotent)
├── profiles/
│   ├── default.profile         Fallback: plain Wine, no shims
│   └── iar.profile             IAR Embedded Workbench
├── sv/
│   └── binfmt-wine-shim/
│       └── run                 runit one-shot service
└── examples/
    └── iar-cli-wrap            Per-tool user wrapper for ~/.local/bin
```

## Quick start

### Prerequisites

Install Wine and support packages via your package manager.

**Void Linux:**

```sh
sudo xbps-install -Sy wine wine-mono winetricks
```

**Other distros:** install `wine` (>= 9.x), `wine-mono`, and `winetricks`.

### Build & install

```sh
git clone <this-repo> && cd wine-shim
make
sudo make install
sudo make enable    # symlink runit service into /var/service/
sudo make setup     # populate host-dmi, load binfmt_misc, register handler
```

### Set up a Wine prefix (IAR example)

```sh
export WINEPREFIX="$HOME/.wine-iar"
export WINEARCH=win64
wineboot --init
winetricks -q vcrun2019     # provides mfc140u.dll needed by iarbuild.exe
```

### Symlink the Windows installation into the prefix

Assuming your Windows partition is mounted at `/run/media/$USER/System`:

```sh
WIN=/run/media/$USER/System
PREFIX="$HOME/.wine-iar/drive_c"

# IAR installation
ln -sfn "$WIN/Program Files/IAR Systems" "$PREFIX/Program Files/IAR Systems"

# License data (Sentinel RMS cache)
ln -sfn "$WIN/ProgramData/IARSystems" "$PREFIX/ProgramData/IARSystems"

# User-specific IAR settings
mkdir -p "$PREFIX/users/$USER/AppData/Local"
ln -sfn "$WIN/Users/$USER/AppData/Local/IAR Embedded Workbench" \
        "$PREFIX/users/$USER/AppData/Local/IAR Embedded Workbench"
```

Map the Windows root as a drive letter so Wine paths resolve:

```sh
ln -sfn "$WIN" "$HOME/.wine-iar/dosdevices/z:"
ln -sfn /      "$HOME/.wine-iar/dosdevices/y:"
```

### Place the `.wineshim` marker

Drop a file named `.wineshim` whose first line is the profile name anywhere
in the directory ancestry of the `.exe` files you want to run:

```sh
echo iar | sudo tee "$WIN/Program Files/IAR Systems/.wineshim"
```

### Install user wrappers (optional)

The `examples/iar-cli-wrap` script resolves `$IAR_BASE/<name>.exe` from its
own `argv[0]`, so you can symlink it as multiple tool names:

```sh
install -m 0755 examples/iar-cli-wrap ~/.local/libexec/iar-cli-wrap
for tool in iarbuild iarchive iasmarm iccarm ilinkarm ielftool iobjmanip isymexport; do
    ln -sfn ~/.local/libexec/iar-cli-wrap ~/.local/bin/$tool
done
```

Set `IAR_BASE` if your install path differs from the default:

```sh
export IAR_BASE="/run/media/$USER/System/Program Files/IAR Systems/Embedded Workbench 9.2"
```

### Verify

```sh
# Direct .exe invocation (via binfmt_misc)
/path/to/iarbuild.exe -?

# Via user wrapper
iccarm --cpu Cortex-M0 -o hello.o hello.c

# Check SMBIOS UUID match
wine-shim-run iar wmic csproduct get uuid
```

## Adding a new profile

1. Create `/etc/wine-shim/profiles/<name>.profile` (or under
   `~/.config/wine-shim/profiles/`).

2. Export Wine environment variables:

   ```sh
   export WINEPREFIX="$HOME/.wine-myapp"
   export WINEARCH=win64
   export WINEDEBUG="${WINEDEBUG:--all}"

   # If the program needs SMBIOS identity:
   export WINE_SHIM_LIBS="machine-id"
   export WINE_SHIM_MACHINE_ID_FILE=/etc/wine-shim/machine-ids/host-dmi

   # If it needs a custom (non-host) machine-id:
   # export WINE_SHIM_MACHINE_ID_FILE=/etc/wine-shim/machine-ids/my-custom-id
   ```

3. Run the program:

   ```sh
   wine-shim-run myprofile /path/to/app.exe --args
   ```

   Or place a `.wineshim` file with the profile name and run the `.exe` directly.

## Adding a new shim

1. Drop `foo.c` into `shims/`.
2. Add `foo` to the `SHIMS` variable in `shims/Makefile`.
3. `make && sudo make install-shims`.
4. Reference it in a profile: `export WINE_SHIM_LIBS="machine-id foo"`.

## How the SMBIOS byte-swap compensation works

Real Windows BIOS stores the UUID with the first three fields in
little-endian byte order. When Windows displays it (via WMI/`wmic`), it
reverses those three fields to produce the standard dash-separated UUID
string. Wine's `get_system_uuid()` in `ntdll/unix/system.c` copies the
32-hex-char machine-id straight into the SMBIOS structure _without_
reversal. This means:

| Source             | Raw SMBIOS byte 0–3 | Displayed UUID field 1 |
|--------------------|----------------------|------------------------|
| Real Windows       | `35 43 44 37`        | `37444335`             |
| Wine (naive copy)  | `37 44 43 35`        | `37444335`             |

The displayed UUID matches, but the **raw bytes** — which is what Sentinel
RMS hashes for the hardware fingerprint — differ.

`wine-shim-dmi-id` pre-reverses the displayed UUID so that after Wine's
naive copy the raw bytes end up identical to real Windows:

```
Displayed UUID:  37444335-3532-5839-474C-F430B9934B93
Pre-swapped:     3543443732353958474cf430b9934b93
Wine copies →    raw bytes: 35 43 44 37 32 35 39 58 47 4C F4 30 B9 93 4B 93
                 (matches real Windows exactly)
```

## License

MIT
