# Replit Shell Init: .bashrc and .config/bashrc

## Discovery (2026-06-27)

`hermes` was not found in fresh Replit terminals despite being installed in `.pythonlibs/bin/`.

## Root Cause

Replit's `~/.bashrc` is a **read-only file from the Nix store** (symlink). It cannot be edited. It does NOT source `~/.profile` (which is only for login shells). Replit terminals are **non-login interactive shells** — they only read `.bashrc`.

The `.bashrc` contains this check near the end:
```bash
if [[ -f "${BASHRC}" ]] && [[ -z "${REPLIT_MODE}" ]]; then
    source "${BASHRC}"   # BASHRC = $HOME/.config/bashrc
fi
```

Where `BASHRC="${REPL_HOME}/.config/bashrc"`.

## Fix

Create `~/.config/bashrc` with PATH additions. This is the ONLY user-writable file sourced by Replit's shell init:

```bash
cat > ~/.config/bashrc << 'EOF'
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/workspace/.pythonlibs/bin" ] && PATH="$HOME/workspace/.pythonlibs/bin:$PATH"
export PATH
EOF
```

## What Does NOT Work

- **`.profile`** — only read by login shells (`bash -l`). Replit terminals are non-login.
- **Editing `~/.bashrc`** — read-only (Nix store symlink). `patch`/`write_file` fail with permission denied.
- **`.bash_profile`** — doesn't exist and wouldn't be read by non-login shells anyway.
- **Relying on `hermes.sh` exports** — only affect that script's subprocess, not new terminal sessions.

## The Full PATH Chain in a Replit Terminal

1. Terminal spawns `bash` (non-login interactive)
2. `/nix/store/.../bashrc` is sourced (read-only)
3. `SHELL_ENV=/run/replit/env/latest` is sourced — sets Nix PATH
4. `~/.config/bashrc` is sourced (if exists) — user PATH additions
5. User gets a prompt with the combined PATH
