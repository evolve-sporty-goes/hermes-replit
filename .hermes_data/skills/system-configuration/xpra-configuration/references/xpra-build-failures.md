# xpra Build Failures in Replit/Nix Environment

## Root Cause
Replit's Nix environment lacks C runtime files and system development headers required for building C/Cython extensions from source.

## Error: Missing crti.o
```
/nix/store/.../bin/ld: cannot find crti.o: No such file or directory
collect2: error: ld returned 1 exit status
```
**Fix:** Not fixable in Replit's user-space Nix. Requires proper nix-shell with `stdenv.cc` and glibc development files.

## Error: pkg-config Dependencies

| Package | Nix Package | Status |
|---------|-------------|--------|
| `libc` | glibc | Partial |
| `xproto` / `x11` | xorgproto | Works via `share/pkgconfig` |
| `xdmcp` | libxdmcp | **Not in nixpkgs** |
| `libxxhash` | xxHash | Works via dev output |
| `sysprof-capture-4` | sysprof | **Not in nixpkgs** (gtk3 dep) |
| `gtk+-3.0` | gtk+3 | Pulls many missing deps |

## Error: Package xdmcp Not Found
```
Package xdmcp was not found in the pkg-config search path.
Perhaps you should add the directory containing `xdmcp.pc'
to the PKG_CONFIG_PATH environment variable
No package 'xdmcp' found
```
**Fix:** `libxdmcp` not available in nixpkgs by that name. The actual package structure differs.

## Error: sysprof-capture-4 (gtk3 dependency)
```
Package sysprof-capture-4 was not found in the pkg-config search path.
Package 'sysprof-capture-4', required by 'glib-2.0', not found
```
**Fix:** Requires `sysprof` which isn't in standard nixpkgs for gtk3.

## Build Switches That Avoid Failures

```bash
python3 ./setup.py install \
  --without-x11 --without-gtk3 --without-gtk_x11 \
  --without-gstreamer --without-pytorch --without-v4l2 \
  --without-webcam --without-notifications --without-dbus \
  --without-pam --without-mdns --without-cairo --without-xinput \
  --without-client --without-clipboard --without-argb --without-audio \
  --without-codecs --without-decoders --without-encoders \
  --without-rfb --without-ssh --without-ssl --without-yaml \
  --without-wayland_client --without-wayland_server
```

Even with maximal `--without-*` flags, builds fail on `crti.o` missing.

## Conclusion

**Do not build xpra from source on Replit.** Use nix-installed version:
```bash
nix-env -iA nixpkgs.xpra
# Gives xpra v6.3 with all features pre-compiled
```

## Working Alternative

1. Install xpra via nix: `nix-env -iA nixpkgs.xpra`
2. Copy HTML5 assets to writable location for patching
3. Start with `--html=/path/to/patched/www`

This avoids all build issues and provides a fully functional xpra server.