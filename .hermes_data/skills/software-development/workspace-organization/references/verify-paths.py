#!/usr/bin/env python3
"""
Workspace path-consistency verification script.
Run via: python3 references/verify-paths.py
Or copy to /tmp and run there.

Checks:
1. .gitignore rules match actual file locations
2. All scripts reference NEW paths (not old root-level paths)
3. All sensitive.txt paths exist on disk
4. git check-ignore works for all sensitive files
"""
import json, os, subprocess, sys

WORKSPACE = "/home/runner/workspace"
errors = []
checked = 0

# --- Config: define your moved files here ---
SENSITIVE_FILES = [
    "scripts/email.sh",
    "credentials/.pat",
    ".hermes_data/.env",
    ".hermes_data/auth.json",
    "credentials/openrouter_credentials.txt",
    "credentials/firecrawl_credentials.txt",
    "credentials/torbox_credentials.txt",
    "credentials/.supabase_anon_key",
]

OLD_ROOT_PATHS = [
    "/home/runner/workspace/email.sh",
    "/home/runner/workspace/.pat",
    "/home/runner/workspace/openrouter_credentials.txt",
    "/home/runner/workspace/firecrawl_credentials.txt",
    "/home/runner/workspace/torbox_credentials.txt",
    "/home/runner/workspace/.supabase_anon_key",
    "/home/runner/workspace/mail.txt",
]

# --- 1. Check .gitignore with git check-ignore ---
print("=== .gitignore check ===")
for f in SENSITIVE_FILES:
    full = os.path.join(WORKSPACE, f)
    result = subprocess.run(
        ["git", "check-ignore", full],
        capture_output=True, text=True, cwd=WORKSPACE
    )
    checked += 1
    if result.returncode != 0:
        errors.append(f"gitignore: {f} is NOT ignored (exit {result.returncode})")
    else:
        print(f"  ✓ {f}")

# --- 2. Check scripts for old root-level paths ===
print("\n=== Old path references ===")
script_dir = os.path.join(WORKSPACE, "scripts")
for fname in sorted(os.listdir(script_dir)):
    fpath = os.path.join(script_dir, fname)
    if not os.path.isfile(fpath):
        continue
    with open(fpath) as f:
        content = f.read()
    for old in OLD_ROOT_PATHS:
        if old not in content:
            continue
        # Substring check: is this old path a prefix of a new path?
        # e.g. "mail.txt" is a prefix of "credentials/mail.txt"
        # We look for the old string NOT preceded by "scripts/" or "credentials/"
        idx = 0
        while True:
            pos = content.find(old, idx)
            if pos == -1:
                break
            preceding = content[max(0, pos-20):pos]
            if "scripts/" not in preceding and "credentials/" not in preceding:
                # Check if it's in a comment line
                line_start = content.rfind('\n', 0, pos) + 1
                line_end = content.find('\n', pos)
                if line_end == -1:
                    line_end = len(content)
                line = content[line_start:line_end]
                if not line.strip().startswith('#'):
                    errors.append(f"{fname}: OLD path '{old}' still referenced")
                    break
            idx = pos + len(old)
    checked += 1
print(f"  Checked {len(os.listdir(script_dir))} files")

# --- 3. Check sensitive.txt paths exist ===
print("\n=== sensitive.txt existence ===")
sens_path = os.path.join(WORKSPACE, "sensitive.txt")
if os.path.exists(sens_path):
    with open(sens_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            checked += 1
            if not os.path.exists(line):
                errors.append(f"sensitive.txt → missing: {line}")
            else:
                print(f"  ✓ {line}")

# --- 4. Check all expected files exist at new locations ===
print("\n=== File existence ===")
for f in SENSITIVE_FILES:
    full = os.path.join(WORKSPACE, f)
    checked += 1
    if not os.path.exists(full):
        errors.append(f"Expected file missing: {f}")
    else:
        print(f"  ✓ {f}")

# --- Summary ---
print(f"\n=== RESULT ===")
print(f"Checks: {checked}, Errors: {len(errors)}")
if errors:
    for e in errors:
        print(f"  ✗ {e}")
    print("STATUS: FAIL")
    sys.exit(1)
else:
    print("STATUS: PASS")
