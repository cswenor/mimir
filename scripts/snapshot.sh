#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get root directory
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Function to create snapshot
create_snapshot() {
    local output_file=$1
    echo "Creating snapshot in: $output_file"
    
    # Create directory listing with permissions, ownership, and timestamps
    (
        echo "=== Directory Structure ==="
        find . -type d -not -path "*/\.*" | sort
        
        echo -e "\n=== Full Details ==="
        find . -not -path "*/\.*" -ls | sort
        
        echo -e "\n=== File Permissions ==="
        find . -not -path "*/\.*" -printf "%M %u:%g %p\n" | sort
        
        echo -e "\n=== Directory Sizes ==="
        du -h -d 3
    ) > "$output_file"
    
    echo -e "${GREEN}Snapshot created: ${BLUE}$output_file${NC}"
}

# Create timestamped filename
timestamp=$(date +%Y%m%d_%H%M%S)

case "$1" in
    "pre")
        create_snapshot "${ROOT_DIR}/snapshot_pre_${timestamp}.txt"
        ;;
    "post")
        create_snapshot "${ROOT_DIR}/snapshot_post_${timestamp}.txt"
        ;;
    *)
        echo "Usage: $0 {pre|post}"
        echo "  pre  - Create snapshot before docker-compose up"
        echo "  post - Create snapshot after docker-compose up"
        exit 1
        ;;
esac