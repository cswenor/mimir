#!/bin/bash

# Exit on error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default settings
VERBOSE=0

# Get the directory paths
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_DIR="$ROOT_DIR/scripts"

# Function to log verbose messages
log() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Function to show error messages
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Function to display help
show_help() {
    echo -e "${BOLD}Mimir Initialization Script${NC}"
    echo "Usage: $0 [-v] [-h]"
    echo
    echo "Options:"
    echo "  -v    Verbose mode"
    echo "  -h    Show this help message"
    echo
    echo "For complete environment reset, use: ./scripts/reset-mimir-environment.sh"
    echo
    exit 0
}

# Parse command line arguments
while getopts "vh" opt; do
    case $opt in
        v)
            VERBOSE=1
            ;;
        h)
            show_help
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            ;;
    esac
done

# Verify scripts directory exists
if [ ! -d "$SCRIPT_DIR" ]; then
    error "Scripts directory not found at: $SCRIPT_DIR"
fi

# Main initialization logic
main() {
    echo -e "${BOLD}Starting Mimir initialization...${NC}"
    echo "==============================="
    
    log "Root directory: $ROOT_DIR"
    log "Scripts directory: $SCRIPT_DIR"
    
    # We're already in the root directory, but let's verify
    cd "$ROOT_DIR"
    log "Verified working directory: $(pwd)"

    # First check all dependencies
    echo -e "\n${YELLOW}Checking dependencies...${NC}"
    log "Running dependency check script"
    if ! "$SCRIPT_DIR/check-dependencies.sh" $([ $VERBOSE -eq 1 ] && echo "-v"); then
        error "Dependency check failed. Please fix the above issues and try again."
    fi
    echo -e "${GREEN}Dependencies check passed.${NC}"

    # Generate .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        echo -e "\n${YELLOW}Generating .env file...${NC}"
        log "Running environment generation script"
        if ! node "$SCRIPT_DIR/generate-env.js"; then
            error "Failed to generate .env file"
        fi
        echo -e "${GREEN}Successfully generated .env file${NC}"
    else
        echo -e "\n${YELLOW}Using existing .env file${NC}"
        log "Found existing .env file"
    fi

    # Generate required files using values from .env
    echo -e "\n${YELLOW}Generating required files...${NC}"
    log "Running file generation script"
    if ! node "$SCRIPT_DIR/generate-files.js"; then
        error "Failed to generate required files"
    fi
    echo -e "${GREEN}Successfully generated required files${NC}"

    echo -e "\n${GREEN}${BOLD}✓ Initialization complete!${NC}"
    echo -e "You can now start the services with: ${YELLOW}docker-compose up -d${NC}"

    # Additional verbose information
    if [ $VERBOSE -eq 1 ]; then
        echo -e "\n${BLUE}Debug Information:${NC}"
        echo "- Working Directory: $ROOT_DIR"
        echo "- Node.js Version: $(node --version)"
        echo "- NPM Version: $(npm --version)"
        echo "- Docker Version: $(docker --version)"
        echo "- Docker Compose Version: $(docker-compose --version)"
    fi
}

# Run main function
main

log "Script completed successfully"