#!/usr/bin/env python3
"""Replace playwright → cloakbrowser in all script files.

Reads each file, applies pattern replacements, writes back.
Usage: python3 scripts/cloak_replace.py
"""

import re
import os

FILES = [
    "scripts/torbox-full-tor-signup.sh",
    "scripts/torbox-full-signup.sh",
    "scripts/torbox-signup.sh",
    "scripts/magiclink.sh",
    "scripts/backup.sh",
    "scripts/firecrawl_gen.py",
]

BACKUP = True


def replace_in_file(path):
    with open(path) as f:
        content = f.read()

    original = content

    # 1. Import line
    content = re.sub(
        r"from playwright\.sync_api import sync_playwright",
        "from cloakbrowser import launch, launch_persistent_context",
        content,
    )

    # 2. `` → remove wrapper, un-indent body
    #    Find: "\n    <indented_block>"
    #    Replace with: "<dedented_block>"
    #    We match the `with` line + everything indented under it until same/less indent
    def dedent_sync_block(m):
        indent = m.group(1)
        body = m.group(2)
        # Remove one level of indentation from body
        lines = body.split("\n")
        dedented = []
        for line in lines:
            if line.startswith(indent):
                dedented.append(line[len(indent) :])
            else:
                dedented.append(line)
        return "\n".join(dedented)

    content = re.sub(
        r"^([ \t]*)with sync_playwright\(\) as p:\n((?:\1[^\n]*\n)*)",
        dedent_sync_block,
        content,
        flags=re.MULTILINE,
    )

    # 3. launch_persistent_context → launch_persistent_context
    content = re.sub(
        r"p\.chromium\.launch_persistent_context",
        "launch_persistent_context",
        content,
    )


    # 5. Add humanize=True to launch_persistent_context calls if not present
    def add_humanize(m):
        call = m.group(0)
        if "humanize=" not in call:
            return call.rstrip(")") + ", humanize=True)"
        return call

    content = re.sub(
        r"launch_persistent_context\([^)]*\)",
        add_humanize,
        content,
    )

    # 6. Remove p.stop() lines
    content = re.sub(r"\n[ \t]*p\.stop\(\)[ \t]*\n", "\n", content)

    if content != original:
        if BACKUP:
            with open(path + ".bak", "w") as f:
                f.write(original)
        with open(path, "w") as f:
            f.write(content)
        print(f"  ✓ {path} (backup: {path}.bak)")
    else:
        print(f"  - {path} (no changes)")


def main():
    for f in FILES:
        if not os.path.exists(f):
            print(f"  ✗ {f} not found, skipping")
            continue
        replace_in_file(f)

    print("\n✓ Done. Run scripts with: xvfb-run python3 scripts/SCRIPT.py")


if __name__ == "__main__":
    main()
