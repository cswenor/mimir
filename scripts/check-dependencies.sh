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

# Check for jq dependency
echo "Checking for jq dependency..."
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq is not installed. Attempting to install...${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq || error "Failed to install jq using apt-get" 16
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq || error "Failed to install jq using yum" 16
    elif command -v brew &> /dev/null; then
        brew install jq || error "Failed to install jq using brew" 16
    else
        error "Package manager not found. Please install jq manually: https://stedolan.github.io/jq/download/" 16
    fi
    echo -e "${GREEN}✓ jq installed successfully${NC}"
else
    log "jq is already installed"
fi

# Check for Git
echo "Checking for Git..."
if ! command -v git &> /dev/null; then
    error "Git is not installed. Please install Git: https://git-scm.com/downloads" 17
fi
echo -e "${GREEN}✓ Git is installed${NC}"

# Check for Docker
echo "Checking for Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker: https://docs.docker.com/get-docker/" 18
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check for Docker Compose
echo "Checking for Docker Compose..."
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    error "Docker Compose is not installed. Please install Docker Compose: https://docs.docker.com/compose/install/" 19
fi
echo -e "${GREEN}✓ Docker Compose is installed${NC}"

# Check Node.js version
echo "Checking Node.js version..."
if ! command -v node &> /dev/null; then
    error "Node.js is not installed. Please install Node.js 16 or higher: https://nodejs.org/" 20
fi

NODE_VERSION=$(node -v | cut -d 'v' -f 2)
version_compare "$NODE_VERSION" "16.0.0"
if [ $? -eq 2 ]; then
    error "Node.js version must be 16.0.0 or higher. Current version: $NODE_VERSION" 21
fi
echo -e "${GREEN}✓ Node.js version $NODE_VERSION is compatible${NC}"

# Check for Supabase CLI
echo "Checking for Supabase CLI..."
if ! command -v supabase &> /dev/null; then
    echo -e "${YELLOW}Supabase CLI is not installed. Attempting to install...${NC}"
    if command -v brew &> /dev/null; then
        brew install supabase/tap/supabase || error "Failed to install Supabase CLI using Homebrew" 22
    else
        curl -fsSL https://cli.supabase.com/install | sh || error "Failed to install Supabase CLI" 22
    fi
    echo -e "${GREEN}✓ Supabase CLI installed successfully${NC}"
else
    log "Supabase CLI is already installed"
fi

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

# Check npm dependencies
echo "Checking npm dependencies..."
log "Looking for package.json in: $ROOT_DIR"

if [ ! -f "$ROOT_DIR/package.json" ]; then
    error "package.json not found in project root: $ROOT_DIR" 12
fi

# Always run npm install to ensure dependencies are up to date
echo -e "${YELLOW}Installing npm dependencies...${NC}"
log "Running npm install in: $ROOT_DIR"
cd "$ROOT_DIR" || error "Failed to change to root directory" 14

# Run npm install with error checking
if ! npm install; then
    error "Failed to install npm dependencies. Check the error messages above." 13
fi

echo -e "${GREEN}✓ npm dependencies installed${NC}"

# Add node_modules check after installation
if [ ! -d "$ROOT_DIR/node_modules" ]; then
    error "node_modules directory not found after npm install" 15
fi

# Ensure dependencies are checked correctly
echo -e "\n${GREEN}✓ All dependency checks passed!${NC}"
echo "You can proceed with the installation."