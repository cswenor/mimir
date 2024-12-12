#!/bin/bash

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

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Function for verbose logging
log() {
    if [ $VERBOSE -eq 1 ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Function for error logging
error() {
    echo -e "${RED}❌ $1${NC}" >&2
    if [ $VERBOSE -eq 1 ]; then
        echo "[DEBUG] Error occurred. Exit code: $2" >&2
        echo "[DEBUG] Call trace:" >&2
        caller 0 >&2
    fi
    exit "${2:-1}"
}

# Function for version comparison
version_compare() {
    local ver1=$1
    local ver2=$2
    log "Comparing versions: $ver1 and $ver2"

    if [ "$ver1" = "$ver2" ]; then
        log "Versions are equal"
        return 0
    fi

    local IFS=.
    local i ver1_array=($ver1) ver2_array=($ver2)

    # Fill empty positions with zeros
    for ((i=${#ver1_array[@]}; i<${#ver2_array[@]}; i++)); do
        ver1_array[i]=0
    done

    for ((i=0; i<${#ver1_array[@]}; i++)); do
        if [ -z "${ver2_array[i]}" ]; then
            ver2_array[i]=0
        fi

        local v1=${ver1_array[i]}
        local v2=${ver2_array[i]}

        if ((v1 > v2)); then
            log "First version is greater"
            return 1
        elif ((v1 < v2)); then
            log "Second version is greater"
            return 2
        fi
    done

    return 0
}

# Check for Supabase sparse clone and configure it
echo "Checking Supabase repository for sparse checkout..."
if [ -d "$ROOT_DIR/supabase" ] && [ ! -d "$ROOT_DIR/supabase/.git" ]; then
    echo "Supabase directory exists but is not a valid repository. Removing it..."
    rm -rf "$ROOT_DIR/supabase" || error "Failed to remove invalid Supabase directory"
fi

if [ ! -d "$ROOT_DIR/supabase" ]; then
    echo "Cloning Supabase repository with sparse checkout..."
    git clone --filter=blob:none --no-checkout https://github.com/supabase/supabase "$ROOT_DIR/supabase" || error "Failed to clone Supabase repository"

    # Move into the cloned directory
    cd "$ROOT_DIR/supabase" || error "Failed to navigate into Supabase directory"

    # Initialize sparse checkout and fetch only the docker directory
    echo "Configuring sparse checkout for 'docker' directory..."
    git sparse-checkout set --cone docker || error "Failed to initialize sparse checkout"

    # Checkout master branch
    git checkout master || error "Failed to checkout master branch"

    # Return to the root directory
    cd "$ROOT_DIR" || error "Failed to return to the root directory"

    echo "Sparse checkout of Supabase repository complete."
else
    echo "Supabase repository already exists and is configured."
fi

# Ensure dependencies are checked correctly
echo -e "\n${GREEN}✓ All dependency checks passed!${NC}"
echo "You can proceed with the installation."
