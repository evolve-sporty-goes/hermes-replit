#!/usr/bin/env bash
# Repair a corrupted Hermes state.db (SQLite FTS b-tree page corruption)
# When `hermes sessions repair` and `hermes doctor --fix` both fail,
# dump what's salvageable via Python and rebuild a clean database.
#
# Symptoms:
#   - Doctor reports "state.db fails a write-health probe"
#   - Error: "btreeInitPage() returns error code 11" / "database disk image is malformed"
#   - `hermes sessions repair` prints same errors and exits without recovery
#
# Usage: bash state-db-corruption-repair.sh
# Works from $HERMES_HOME or ~/.hermes by default.

set -euo pipefail

DB_DIR="${HERMES_HOME:-$HOME/.hermes/state-db-corruption-repair}"
DB="${DB_DIR}/state.db"

if [ ! -f "$DB" ]; then
  echo "ERROR: state.db not found at $DB"
  exit 1
fi

cd "$DB_DIR"

# Step 1: Dump readable tables via Python (survives corrupt FTS pages)
echo "Step 1: Dumping readable tables..."
python3 << 'PYEOF'
import sqlite3, os

src_path = "state.db"
dump_path = "dump.sql"
corrupt_backup = "state.db.corrupt"

# Backup current corrupt file
import shutil
if not os.path.exists(corrupt_backup):
    shutil.copy2(src_path, corrupt_backup)
    print(f"  Backed up to {corrupt_backup}")

src = sqlite3.connect(src_path)

# Get non-FTS tables
tables = [r[0] for r in src.execute(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE '%fts%'"
).fetchall()]

print(f"  Found tables: {', '.join(tables)}")

# Dump schema + data for each non-FTS table
with open(dump_path, "w") as f:
    for table in tables:
        # Schema
        schema = src.execute(
            f"SELECT sql FROM sqlite_master WHERE name='{table}'"
        ).fetchone()
        if schema and schema[0]:
            f.write(schema[0] + ";\n")
            print(f"  Schema: {table}")

        # Data
        try:
            rows = src.execute(f"SELECT * FROM {table}").fetchall()
            if rows:
                cols = len(rows[0])
                placeholders = ",".join(["?"] * cols)
                f.write(f"-- DATA: {table} ({len(rows)} rows)\n")
                for row in rows:
                    vals = ",".join(
                        f"'{str(v).replace(chr(39), chr(39)+chr(39))}'"
                        if v is not None else "NULL"
                        for v in row
                    )
                    f.write(f"INSERT INTO {table} VALUES ({vals});\n")
            print(f"  Data: {table} ({len(rows)} rows)")
        except Exception as e:
            print(f"  Data: {table} COPY SKIPPED ({e})")

src.close()
print("  Dump complete.")
PYEOF

# Step 2: Rebuild clean database from dump
echo "Step 2: Rebuilding clean database..."
python3 << 'PYEOF'
import sqlite3, os

dump_path = "dump.sql"
new_path = "state.db.new"
old_path = "state.db"

if os.path.exists(new_path):
    os.remove(new_path)

lines = open(dump_path).readlines()
conn = sqlite3.connect(new_path)

ok = 0
skipped = 0
for line in lines:
    line = line.strip()
    if not line or line.startswith("--"):
        continue
    try:
        conn.execute(line)
        ok += 1
    except Exception:
        skipped += 1

conn.commit()

# Report
tables = [r[0] for r in conn.execute(
    "SELECT name FROM sqlite_master WHERE type='table'"
).fetchall()]
print(f"  Rebuilt: {ok} statements OK, {skipped} skipped")
for t in tables:
    c = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    print(f"    {t}: {c} rows")

conn.close()

# Verify integrity
conn = sqlite3.connect(new_path)
check = conn.execute("PRAGMA integrity_check").fetchone()[0]
conn.close()
print(f"  Integrity check: {check}")
PYEOF

# Step 3: Swap in the clean database
echo "Step 3: Swapping clean database in..."
mv state.db state.db.broken
mv state.db.new state.db
echo "  Done. Old DB preserved as state.db.broken"
echo ""
echo "Repair complete. Run 'hermes doctor' to verify."
