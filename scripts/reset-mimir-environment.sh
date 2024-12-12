#!/bin/bash

# Default settings
VERBOSE=0
FORCE=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Parse command line arguments
while getopts "vf" opt; do
    case $opt in
        v)
            VERBOSE=1
            ;;
        f)
            FORCE=1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Function for verbose logging
log() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Function to remove directory contents but keep the directory
clean_directory() {
    local dir=$1
    if [ -d "$dir" ]; then
        log "Cleaning directory: $dir"
        # Remove everything except .gitkeep
        find "$dir" -mindepth 1 -not -name '.gitkeep' -exec rm -rf {} +
        log "Directory cleaned: $dir"
    else
        log "Directory does not exist: $dir"
        mkdir -p "$dir"
        log "Created directory: $dir"
    fi
    # Ensure .gitkeep exists
    touch "$dir/.gitkeep"
    log "Ensured .gitkeep exists in: $dir"
}

# Function to confirm action with custom warning
confirm() {
    local message=$1
    local confirmation_word=$2
    
    echo -e "\n${RED}${BOLD}⚠️  WARNING: DESTRUCTIVE OPERATION ⚠️${NC}"
    echo -e "${RED}${BOLD}=====================================${NC}"
    echo -e "${RED}This operation will:${NC}"
    echo -e "${RED}1. Stop all running Mimir containers${NC}"
    echo -e "${RED}2. Delete all blockchain data${NC}"
    echo -e "${RED}3. Remove all environment configurations${NC}"
    echo -e "${RED}4. Remove all dependencies${NC}"
    echo -e "${RED}5. Reset all generated files${NC}"
    
    echo -e "\n${YELLOW}${BOLD}To verify this action:${NC}"
    echo -e "1. Type ${BOLD}'RESET-MIMIR'${NC} to confirm you want to reset"
    echo -e "2. Then type ${BOLD}'START_FRESH'${NC} to confirm data deletion"
    
    echo -e "\nType ${BOLD}'RESET-MIMIR'${NC} to begin: "
    read -r response1
    
    if [ "$response1" != "RESET-MIMIR" ]; then
        return 1
    fi

    echo -e "\n${RED}${BOLD}FINAL WARNING:${NC}"
    echo -e "${RED}You are about to delete all data and configurations.${NC}"
    echo -e "${RED}This cannot be undone!${NC}"
    echo -e "\nType ${BOLD}'START_FRESH'${NC} to confirm permanent deletion: "
    read -r response2
    
    if [ "$response2" != "START_FRESH" ]; then
        return 1
    fi
    
    return 0
}

# Function to reset environment
reset_environment() {
    echo -e "${BLUE}${BOLD}Mimir Environment Reset Tool${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    # Get the script directory and root directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    
    log "Script directory: $SCRIPT_DIR"
    log "Root directory: $ROOT_DIR"
    
    # Change to root directory
    cd "$ROOT_DIR"
    log "Changed working directory to: $(pwd)"

    # List of files/directories to remove completely
    declare -a items_to_remove=(
        ".env"
        "node_modules"
        "package-lock.json"
    )

    # List of directories to clean but preserve
    declare -a dirs_to_clean=(
        "algod-data"
        "conduit-data"
    )

    if [ $FORCE -ne 1 ]; then
        echo -e "${BOLD}Current working directory: ${YELLOW}$(pwd)${NC}"
        
        echo -e "\nThe following items will be removed:"
        for item in "${items_to_remove[@]}"; do
            echo -e "${YELLOW}- $item${NC}"
        done
        echo -e "\nThe following directories will be cleaned:"
        for dir in "${dirs_to_clean[@]}"; do
            echo -e "${YELLOW}- ${dir}/*${NC}"
        done
        
        # Require explicit double confirmation
        if ! confirm "Preparing to reset environment" "START_FRESH"; then
            echo -e "\n${YELLOW}Reset cancelled${NC}"
            echo -e "${GREEN}No changes were made to your environment${NC}"
            return 1
        fi
    fi

    # Perform reset
    echo -e "\n${YELLOW}Starting environment reset...${NC}"
    
    # Stop any running containers
    if command -v docker-compose &> /dev/null; then
        log "Stopping Docker containers..."
        docker-compose down &> /dev/null || true
        log "Docker containers stopped"
    else
        log "docker-compose not found, skipping container shutdown"
    fi

    # Remove files and directories completely
    for item in "${items_to_remove[@]}"; do
        local full_path="$ROOT_DIR/$item"
        if [ -e "$full_path" ]; then
            log "Removing: $full_path"
            rm -rf "$full_path"
            log "Successfully removed: $full_path"
        else
            log "Item does not exist, skipping: $full_path"
        fi
    done

    # Clean preserved directories
    for dir in "${dirs_to_clean[@]}"; do
        clean_directory "$ROOT_DIR/$dir"
    done

    echo -e "\n${GREEN}${BOLD}Environment reset complete!${NC}"
    echo -e "You can now run ${YELLOW}init.sh${NC} to reinitialize the environment."
    return 0
}

# Run reset function
reset_environment

log "Script completed"