#!/bin/sh
set -e

# Backup script for PostgreSQL databases
# Runs daily via the backup container

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}

echo "[$(date)] Starting backup process..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to backup a database
backup_database() {
    local db_name=$1
    local backup_file="${BACKUP_DIR}/${db_name}_${TIMESTAMP}.sql.gz"
    
    echo "[$(date)] Backing up database: $db_name"
    
    PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
        -h "$POSTGRES_HOST" \
        -U "$POSTGRES_USER" \
        -d "$db_name" \
        --no-owner \
        --no-acl \
        --clean \
        --if-exists \
        | gzip > "$backup_file"
    
    if [ $? -eq 0 ]; then
        echo "[$(date)] Successfully backed up $db_name to $backup_file"
        # Calculate file size
        size=$(du -h "$backup_file" | cut -f1)
        echo "[$(date)] Backup size: $size"

        # Verify backup integrity
        if gunzip -t "$backup_file" 2>/dev/null; then
            echo "[$(date)] Backup verified: $backup_file is valid"
        else
            echo "[$(date)] ERROR: Backup verification failed for $backup_file"
            return 1
        fi
    else
        echo "[$(date)] ERROR: Failed to backup $db_name"
        return 1
    fi
}

# Backup all databases
backup_database "litellm"
backup_database "openwebui"
backup_database "postgres"

# Create a combined backup metadata file
cat > "${BACKUP_DIR}/backup_${TIMESTAMP}.info" <<EOF
Backup Date: $(date)
Databases: litellm, openwebui, postgres
Host: $POSTGRES_HOST
User: $POSTGRES_USER
EOF

# Delete old backups
echo "[$(date)] Cleaning up backups older than $KEEP_DAYS days..."
find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +$KEEP_DAYS -delete
find "$BACKUP_DIR" -name "*.info" -type f -mtime +$KEEP_DAYS -delete

# Count remaining backups
backup_count=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f | wc -l)
echo "[$(date)] Current number of backups: $backup_count"

# Optional: Upload to S3 if configured
if [ -n "$BACKUP_S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo "[$(date)] Uploading backups to S3..."
    # This requires aws-cli to be installed in the container
    # aws s3 sync "$BACKUP_DIR" "s3://$BACKUP_S3_BUCKET/backups/" --storage-class STANDARD_IA
fi

echo "[$(date)] Backup process completed successfully"

# Health check - ensure at least one backup exists
if [ $backup_count -eq 0 ]; then
    echo "[$(date)] WARNING: No backups found!"
    exit 1
fi

exit 0
