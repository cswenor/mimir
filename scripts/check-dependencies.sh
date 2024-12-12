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

# Required versions
MIN_DOCKER_VERSION="20.10.0"
MIN_DOCKER_COMPOSE_VERSION="2.0.0"
MIN_NODE_VERSION="16.0.0"

# Function to compare versions
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

# Function to check if command exists
command_exists() {
    log "Checking if command exists: $1"
    command -v "$1" >/dev/null 2>&1
}

# Function to extract version from string
extract_version() {
    local input=$1
    log "Extracting version from: $input"
    
    # First try to match version after "version" keyword
    local version
    version=$(echo "$input" | sed -n 's/.*version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
    
    # If that fails, try to match any version number
    if [ -z "$version" ]; then
        log "First version extraction attempt failed, trying alternate method"
        version=$(echo "$input" | grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' | head -n1)
    fi
    
    if [ -z "$version" ]; then
        log "Failed to extract version"
        return 1
    fi
    
    log "Extracted version: $version"
    echo "$version"
    return 0
}

# Print start message
echo "Checking dependencies for Mimir..."
echo "================================"

# Check Docker
echo "Checking Docker..."
if ! command_exists docker; then
    error "Docker is not installed. Please install Docker from https://docs.docker.com/get-docker/" 2
fi

DOCKER_VERSION=$(docker --version)
log "Raw Docker version string: $DOCKER_VERSION"
VERSION_NUM=$(extract_version "$DOCKER_VERSION")

if [ -z "$VERSION_NUM" ]; then
    error "Could not determine Docker version" 3
fi

echo "Docker version: $VERSION_NUM (from: $DOCKER_VERSION)"
version_compare "$VERSION_NUM" "$MIN_DOCKER_VERSION"
case $? in
    0|1)
        echo -e "${GREEN}✓ Docker version $VERSION_NUM${NC}"
        ;;
    2)
        error "Docker version $VERSION_NUM is below minimum required version $MIN_DOCKER_VERSION" 4
        ;;
esac

# Check Docker Compose
echo "Checking Docker Compose..."
if ! command_exists docker-compose; then
    error "Docker Compose is not installed. Please install from https://docs.docker.com/compose/install/" 5
fi

DOCKER_COMPOSE_VERSION=$(docker-compose --version)
log "Raw Docker Compose version string: $DOCKER_COMPOSE_VERSION"
VERSION_NUM=$(extract_version "$DOCKER_COMPOSE_VERSION")

if [ -z "$VERSION_NUM" ]; then
    error "Could not determine Docker Compose version" 6
fi

echo "Docker Compose version: $VERSION_NUM (from: $DOCKER_COMPOSE_VERSION)"
version_compare "$VERSION_NUM" "$MIN_DOCKER_COMPOSE_VERSION"
case $? in
    0|1)
        echo -e "${GREEN}✓ Docker Compose version $VERSION_NUM${NC}"
        ;;
    2)
        error "Docker Compose version $VERSION_NUM is below minimum required version $MIN_DOCKER_COMPOSE_VERSION" 7
        ;;
esac

# Check Node.js
echo "Checking Node.js..."
if ! command_exists node; then
    error "Node.js is not installed. Please install Node.js from https://nodejs.org/" 8
fi

NODE_VERSION=$(node --version)
log "Raw Node.js version string: $NODE_VERSION"
VERSION_NUM=$(extract_version "$NODE_VERSION")

if [ -z "$VERSION_NUM" ]; then
    error "Could not determine Node.js version" 9
fi

echo "Node.js version: $VERSION_NUM (from: $NODE_VERSION)"
version_compare "$VERSION_NUM" "$MIN_NODE_VERSION"
case $? in
    0|1)
        echo -e "${GREEN}✓ Node.js version $VERSION_NUM${NC}"
        ;;
    2)
        error "Node.js version $VERSION_NUM is below minimum required version $MIN_NODE_VERSION" 10
        ;;
esac

# Check if Docker daemon is running
echo "Checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running. Please start the Docker daemon" 11
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Check disk space
echo "Checking disk space..."
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
echo -e "${YELLOW}ℹ Available disk space: $AVAILABLE_SPACE${NC}"
echo -e "${YELLOW}ℹ Recommended minimum: 20GB${NC}"

# Check memory
echo "Checking system memory..."
if command_exists free; then
    TOTAL_MEMORY=$(free -h | awk '/^Mem:/{print $2}')
    echo -e "${YELLOW}ℹ Total system memory: $TOTAL_MEMORY${NC}"
    echo -e "${YELLOW}ℹ Recommended minimum: 8GB${NC}"
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

# All checks passed
echo -e "\n${GREEN}✓ All dependency checks passed!${NC}"
echo "You can proceed with the installation."