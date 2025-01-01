#!/bin/bash
# scripts/backup.sh

# Default to non-verbose
VERBOSE=0

# Parse command line arguments
while getopts "v" opt; do
  case $opt in
    v)
      VERBOSE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Get the directory containing the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MIMIR_HOME="$( cd "$SCRIPT_DIR/.." && pwd )"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function for verbose logging
log() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Function for error logging
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Source the environment file
ENV_FILE="$MIMIR_HOME/supabase/docker/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    log "Loaded environment from $ENV_FILE"
else
    error "Environment file not found at $ENV_FILE"
fi

# Verify required environment variables
required_vars=(
    "POSTGRES_PASSWORD"
    "SERVICE_ROLE_KEY"
    "POSTGRES_DB"
    "POSTGRES_PORT"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        error "Required environment variable $var is not set"
    fi
done

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    error "jq is not installed. Please install it to use the backup feature."
fi

# Set backup name with timestamp
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mimir_backup_${BACKUP_DATE}"

log "Creating backup: ${BACKUP_NAME}"

# Create backup and upload directly to Supabase storage
cd "$MIMIR_HOME/supabase/docker" || error "Failed to change to Supabase directory"

echo -e "${YELLOW}Creating and uploading backup...${NC}"

# Create the backup
if ! supabase db dump --db-url postgresql://postgres:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB} | \
   curl -X POST \
        "${SUPABASE_PUBLIC_URL}/storage/v1/object/backups/${BACKUP_NAME}.sql" \
        -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
        -H "Content-Type: application/octet-stream" \
        --data-binary @- ; then
    error "Failed to create or upload backup"
fi

echo -e "${GREEN}✓ Backup created and uploaded successfully${NC}"

# Prune old backups
echo -e "${YELLOW}Pruning old backups...${NC}"
log "Fetching list of existing backups"

BACKUPS=$(curl -s \
    "${SUPABASE_PUBLIC_URL}/storage/v1/object/list/backups" \
    -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" | \
    jq -r '.[] | select(.name | endswith(".sql")) | {name: .name, created_at: .created_at}' | \
    jq -s 'sort_by(.created_at)') || error "Failed to list existing backups"

# Count total backups
TOTAL_BACKUPS=$(echo $BACKUPS | jq length)
log "Found $TOTAL_BACKUPS total backups"

if [ $TOTAL_BACKUPS -gt 1 ]; then
    # Get all backup names except the newest one that are older than 7 days
    OLD_BACKUPS=$(echo $BACKUPS | \
        jq -r '.[] | select(
            .created_at < (now - 604800 | todate) and
            .created_at != (max_by(.created_at).created_at)
        ) | .name')

    # Delete old backups
    for backup in $OLD_BACKUPS; do
        log "Deleting old backup: $backup"
        if curl -X DELETE \
            "${SUPABASE_PUBLIC_URL}/storage/v1/object/backups/${backup}" \
            -H "Authorization: Bearer ${SERVICE_ROLE_KEY}"; then
            echo -e "${GREEN}✓ Deleted old backup: ${backup}${NC}"
        else
            echo -e "${YELLOW}Warning: Failed to delete backup: ${backup}${NC}"
        fi
    done
fi

echo -e "${GREEN}✓ Backup process completed successfully!${NC}"