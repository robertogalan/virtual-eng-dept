#!/bin/bash
#
# Nightly Backup Script for Vigil (Security + Backup Agent)
# Run via cron at 02:00 UTC
#
# Crontab entry:
# 0 2 * * * /home/openclaw/workspace/scripts/nightly-backup.sh >> /home/openclaw/logs/backup.log 2>&1
#

set -e

# Configuration
BACKUP_DIR="/home/openclaw/backups"
WORKSPACE="/home/openclaw/workspace"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_NAME="backup-$DATE.tar.gz"
RETENTION_DAYS=30

# Optional: S3 bucket for offsite backup
# S3_BUCKET="s3://your-bucket/backups"

echo "========================================"
echo "[$(date)] Starting nightly backup..."
echo "========================================"

# Create backup directory
mkdir -p $BACKUP_DIR

# Find all SQLite databases
echo "[$(date)] Finding databases..."
DB_LIST=$(find $WORKSPACE -name "*.db" -type f 2>/dev/null || true)

if [ -z "$DB_LIST" ]; then
    echo "[$(date)] WARNING: No databases found to backup"
else
    echo "[$(date)] Found databases:"
    echo "$DB_LIST" | while read db; do
        echo "  - $db"
    done
fi

# Create temporary directory for backup staging
STAGING_DIR="/tmp/backup-$TIMESTAMP"
mkdir -p $STAGING_DIR

# Copy databases to staging (to avoid locking issues)
echo "[$(date)] Copying databases to staging..."
echo "$DB_LIST" | while read db; do
    if [ -f "$db" ]; then
        # Preserve directory structure
        REL_PATH="${db#$WORKSPACE/}"
        mkdir -p "$STAGING_DIR/$(dirname $REL_PATH)"
        
        # Use sqlite3 backup command if available, otherwise copy
        if command -v sqlite3 &> /dev/null; then
            sqlite3 "$db" ".backup '$STAGING_DIR/$REL_PATH'"
        else
            cp "$db" "$STAGING_DIR/$REL_PATH"
        fi
    fi
done

# Also backup important config files
echo "[$(date)] Backing up config files..."
mkdir -p $STAGING_DIR/config
cp -r /home/openclaw/.openclaw $STAGING_DIR/config/ 2>/dev/null || true
cp /home/openclaw/workspace/*.md $STAGING_DIR/config/ 2>/dev/null || true

# Create compressed archive
echo "[$(date)] Creating archive: $BACKUP_NAME"
cd $STAGING_DIR
tar -czf "$BACKUP_DIR/$BACKUP_NAME" .

# Cleanup staging
rm -rf $STAGING_DIR

# Verify backup was created
if [ -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
    SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
    echo "[$(date)] ✅ Backup complete: $BACKUP_NAME ($SIZE)"
else
    echo "[$(date)] ❌ ERROR: Backup file not created!"
    exit 1
fi

# Upload to S3 (if configured)
# if [ -n "$S3_BUCKET" ]; then
#     echo "[$(date)] Uploading to S3..."
#     aws s3 cp "$BACKUP_DIR/$BACKUP_NAME" "$S3_BUCKET/$BACKUP_NAME"
#     echo "[$(date)] ✅ S3 upload complete"
# fi

# Prune old backups (keep daily for RETENTION_DAYS, keep weekly indefinitely)
echo "[$(date)] Pruning old backups (keeping $RETENTION_DAYS days)..."
find $BACKUP_DIR -name "backup-*.tar.gz" -mtime +$RETENTION_DAYS | while read old_backup; do
    # Keep weekly backups (Sundays) indefinitely
    BACKUP_DATE=$(basename $old_backup | sed 's/backup-//' | sed 's/.tar.gz//')
    # GNU date uses -d, BSD (macOS) uses -j -f
    if date -d "$BACKUP_DATE" +%u &>/dev/null; then
        DAY_OF_WEEK=$(date -d "$BACKUP_DATE" +%u)
    elif date -j -f "%Y-%m-%d" "$BACKUP_DATE" +%u &>/dev/null; then
        DAY_OF_WEEK=$(date -j -f "%Y-%m-%d" "$BACKUP_DATE" +%u)
    else
        DAY_OF_WEEK="0"
    fi
    
    if [ "$DAY_OF_WEEK" = "7" ]; then
        echo "  Keeping weekly backup: $old_backup"
    else
        echo "  Deleting: $old_backup"
        rm -f "$old_backup"
    fi
done

# List current backups
echo ""
echo "[$(date)] Current backups:"
ls -lah $BACKUP_DIR/backup-*.tar.gz 2>/dev/null | tail -10 || echo "  (none)"

echo ""
echo "========================================"
echo "[$(date)] Backup job finished successfully"
echo "========================================"
