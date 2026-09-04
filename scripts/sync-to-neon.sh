#!/bin/bash
# Neon Cold Standby Sync Script
# Run manually or via GitHub Actions
# Usage: ./scripts/sync-to-neon.sh

set -e

# Config — set these in .env.local or environment
SUPABASE_URL="${SUPABASE_DB_URL:-}"
NEON_URL="${NEON_DB_URL:-}"

if [ -z "$SUPABASE_URL" ]; then
  echo "ERROR: SUPABASE_DB_URL not set"
  exit 1
fi

if [ -z "$NEON_URL" ]; then
  echo "ERROR: NEON_DB_URL not set"
  exit 1
fi

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="backups"
BACKUP_FILE="$BACKUP_DIR/neon_sync_$TIMESTAMP.sql"

echo "=== Neon Cold Standby Sync ==="
echo "Time: $TIMESTAMP"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Step 1: Dump from Supabase
echo "[1/3] Dumping from Supabase..."
pg_dump "$SUPABASE_URL" --schema=public --no-owner --no-privileges --clean --if-exists -f "$BACKUP_FILE"
echo "  Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Step 2: Restore to Neon
echo "[2/3] Restoring to Neon..."
pg_restore -d "$NEON_URL" --no-owner --no-privileges --clean --if-exists "$BACKUP_FILE"

# Step 3: Cleanup old backups (keep 7 days)
echo "[3/3] Cleaning old backups..."
find "$BACKUP_DIR" -name "neon_sync_*.sql" -mtime +7 -delete

echo "=== Sync Complete ==="
