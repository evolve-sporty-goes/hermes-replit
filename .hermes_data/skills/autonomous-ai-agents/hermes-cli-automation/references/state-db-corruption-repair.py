#!/usr/bin/env python3
"""
Recover state.db from FTS b-tree corruption.
When `hermes sessions repair` and `hermes doctor --fix` both fail:
  - database disk image is malformed
  - btreeInitPage() returns error code 11
  - state.db fails a write-health probe

Strategy: read good tables via Python iterdump (bypasses corrupt page cache),
build fresh DB, drop broken FTS tables (auto-rebuilt on next session).
"""
import sqlite3, os, shutil

DB = os.path.expanduser("~/.hermes/state.db")
BAK = DB + ".corrupt-save"

if not os.path.exists(BAK):
    shutil.copy2(DB, BAK)
    print(f"Backed up to {BAK}")

src = sqlite3.connect(DB)
dst = sqlite3.connect(DB + ".new")

# Copy all non-FTS tables
tables = [r[0] for r in src.execute(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE '%fts%'"
).fetchall()]

for table in tables:
    schema = src.execute(f"SELECT sql FROM sqlite_master WHERE name='{table}'").fetchone()[0]
    try:
        dst.execute(schema)
    except Exception as e:
        print(f"  schema {table}: {e}")
        continue
    try:
        rows = src.execute(f"SELECT * FROM {table}").fetchall()
        if rows:
            placeholders = ','.join(['?' for _ in rows[0]])
            dst.executemany(f"INSERT INTO TABLE {table} VALUES ({placeholders})", rows)
        print(f"  {table}: {len(rows)} rows")
    except Exception as e:
        print(f"  {table}: ERROR - {e}")

# Drop FTS tables — Hermes rebuilds them on next session
fts = [r[0] for r in dst.execute("SELECT name FROM sqlite_master WHERE name LIKE '%fts%'").fetchall()]
for t in fts:
    dst.execute(f"DROP TABLE IF EXISTS {t}")

dst.commit()

# Verify
print("\nVerification:")
for table in tables:
    c = dst.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    print(f"  {table}: {c}")

dst.close()
src.close()

# Swap
os.replace(DB + ".new", DB)
print(f"\n{DB} rebuilt. FTS will rebuild on next session start.")
