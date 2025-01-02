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
    grep -v "STUDIO_DEFAULT" "$ENV_FILE" > "$ENV_FILE.tmp"
    set -a
    source "$ENV_FILE.tmp"
    set +a
    rm "$ENV_FILE.tmp"
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
    "SUPABASE_PUBLIC_URL"
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

# Create backup directory if it doesn't exist
BACKUP_DIR="$MIMIR_HOME/supabase/backups"
mkdir -p "$BACKUP_DIR"
log "Created backup directory: $BACKUP_DIR"

# Create the backup
echo -e "${YELLOW}Starting database backup...${NC}"
log "Using database: ${POSTGRES_DB}"
log "Backup file: $BACKUP_DIR/${BACKUP_NAME}.sql"

if ! docker exec supabase-db pg_dump \
    -U postgres \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    --verbose \
    "${POSTGRES_DB}" \
    > "$BACKUP_DIR/${BACKUP_NAME}.sql" \
    2> >(while read -r line; do log "$line"; done); then
    error "Failed to create backup"
fi

log "Backup size: $(du -h "$BACKUP_DIR/${BACKUP_NAME}.sql" | cut -f1)"
echo -e "${GREEN}✓ Backup created successfully${NC}"

echo -e "${YELLOW}Creating backups bucket (or confirming if it already exists)...${NC}"

# Use heredoc to avoid complex quoting issues
docker exec -i supabase-db psql -U postgres -q <<EOF
DO \$\$
BEGIN
    -- Check if the 'backups' bucket already exists
    IF EXISTS (SELECT 1 FROM storage.buckets WHERE name = 'backups') THEN
        RAISE NOTICE 'The backups bucket already exists.';
    ELSE
        -- Create the 'backups' bucket
        INSERT INTO storage.buckets (id, name, owner, public)
        VALUES ('backups', 'backups', auth.uid(), true);

        RAISE NOTICE 'The backups bucket has been created.';
    END IF;

    -- Policy for anon to only read (SELECT)
    BEGIN
        CREATE POLICY "Give anon users read access"
        ON storage.objects
        FOR SELECT
        TO anon
        USING (bucket_id = 'backups');
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy "Give anon users read access" already exists for bucket backups.';
    END;

    -- Policy for service_role to write (INSERT, UPDATE, DELETE) + read
    BEGIN
        CREATE POLICY "Allow service_role writes"
        ON storage.objects
        FOR ALL
        TO service_role
        USING (bucket_id = 'backups')
        WITH CHECK (bucket_id = 'backups');
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy "Allow service_role writes" already exists for bucket backups.';
    END;
END
\$\$;
EOF

# The local backup file
BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}.sql"

echo -e "${YELLOW}Uploading backup to Supabase storage (via REST)...${NC}"

############################
# Additional verbose logging:
############################

# We'll show part of the SERVICE_ROLE_KEY to avoid leaking the entire token in logs.
KEY_FIRST8=${SERVICE_ROLE_KEY:0:8}
KEY_LAST4=${SERVICE_ROLE_KEY: -4}
MASKED_KEY="${KEY_FIRST8}...${KEY_LAST4}"

if [ $VERBOSE -eq 1 ]; then
    log "Uploading to: ${SUPABASE_PUBLIC_URL}/storage/v1/object/backups/${BACKUP_NAME}.sql"
    log "Auth Bearer: ${MASKED_KEY}"
fi

# If VERBOSE=1, add `-v` for more debug info in the curl call.
CURL_ARGS="-s -S -f"
if [ $VERBOSE -eq 1 ]; then
  CURL_ARGS="-v -s -S -f"
fi

# Use a direct upload to the local Supabase Storage API via curl
# SERVICE_ROLE_KEY is used as a Bearer token to bypass RLS.
if ! curl ${CURL_ARGS} -X POST \
  "${SUPABASE_PUBLIC_URL}/storage/v1/object/backups/${BACKUP_NAME}.sql" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"${BACKUP_FILE}"; then
  error "Failed to upload backup with curl"
fi

echo -e "${GREEN}✓ Backup uploaded successfully to Storage${NC}"
