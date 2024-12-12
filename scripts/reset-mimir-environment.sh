#!/bin/bash

# Default settings
VERBOSE=0
FORCE=0

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

# Function to confirm action with custom warning
confirm() {
    local message=$1
    local confirmation_word=$2
    
    echo -e "\n${RED}${BOLD}⚠️  WARNING: DESTRUCTIVE OPERATION ⚠️${NC}"
    echo -e "${RED}${BOLD}=====================================${NC}"
    echo -e "${RED}This operation will:${NC}"
    echo -e "${RED}1. Stop all running Mimir and Supabase containers${NC}"
    echo -e "${RED}2. Delete all blockchain and database data${NC}"
    echo -e "${RED}3. Remove all environment configurations${NC}"
    echo -e "${RED}4. Remove all dependencies${NC}"
    echo -e "${RED}5. Reset all generated files${NC}"
    echo -e "${RED}6. Clean Supabase directory and configurations${NC}"
    
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

needs_sudo() {
    local dir=$1
    if [ -d "$dir" ] && ! [ -w "$dir" ]; then
        return 0  # True, needs sudo
    fi
    if [ -d "$dir" ] && ! [ -w "$dir"/* 2>/dev/null ]; then
        return 0  # True, needs sudo for contents
    fi
    return 1     # False, doesn't need sudo
}

# Function to clean a directory completely
clean_directory() {
    local dir=$1
    local preserve_gitkeep=${2:-0}  # Default to not preserving .gitkeep

    if [ -d "$dir" ]; then
        log "Processing directory: $dir"
        
        if needs_sudo "$dir"; then
            log "Using elevated permissions to remove: $dir"
            echo -e "${YELLOW}Using elevated permissions to clean $dir${NC}"
            
            sudo rm -rf "$dir" || {
                echo -e "${RED}Failed to remove directory with sudo: $dir${NC}"
                return 1
            }
        else
            log "Removing directory with standard permissions: $dir"
            rm -rf "$dir" || {
                echo -e "${RED}Failed to remove directory: $dir${NC}"
                return 1
            }
        fi
        log "Successfully removed directory: $dir"
    else
        log "Directory does not exist, skipping: $dir"
    fi

    # Recreate directory and .gitkeep if needed
    if [ $preserve_gitkeep -eq 1 ]; then
        log "Recreating directory and .gitkeep: $dir"
        if needs_sudo "$dir"; then
            sudo mkdir -p "$dir" || {
                echo -e "${RED}Failed to recreate directory with sudo: $dir${NC}"
                return 1
            }
            sudo chown "$USER:$USER" "$dir" || {
                echo -e "${RED}Failed to set ownership: $dir${NC}"
                return 1
            }
        else
            mkdir -p "$dir" || {
                echo -e "${RED}Failed to recreate directory: $dir${NC}"
                return 1
            }
        fi
        
        touch "$dir/.gitkeep" || {
            echo -e "${RED}Failed to create .gitkeep in: $dir${NC}"
            return 1
        }
        chmod 644 "$dir/.gitkeep" || {
            echo -e "${RED}Failed to set permissions on .gitkeep in: $dir${NC}"
            return 1
        }
        
        log "Successfully recreated directory with .gitkeep: $dir"
    fi

    return 0
}

# Main reset function
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

    # Directories and files to remove
    declare -a items_to_remove=(
        "supabase/docker/volumes"  
        "supabase"             
        "node_modules"
        "package-lock.json"
    )

    # Directories to clean and keep .gitkeep
    declare -a dirs_with_gitkeep=(
        "algod-data"
        "conduit-data"
    )

    if [ $FORCE -ne 1 ]; then
        echo -e "${BOLD}Current working directory: ${YELLOW}$(pwd)${NC}"
        
        echo -e "\nThe following items will be removed:"
        for item in "${items_to_remove[@]}"; do
            echo -e "${YELLOW}- $item${NC}"
        done
        echo -e "\nThe following directories will be cleaned and keep .gitkeep:"
        for dir in "${dirs_with_gitkeep[@]}"; do
            echo -e "${YELLOW}- $dir${NC}"
        done
        
        # Require explicit double confirmation
        if ! confirm "Preparing to reset environment" "START_FRESH"; then
            echo -e "\n${YELLOW}Reset cancelled${NC}"
            echo -e "${GREEN}No changes were made to your environment${NC}"
            return 1
        fi
    fi

    echo -e "\n${YELLOW}Starting environment reset...${NC}"
    
    # Stop and clean up Docker containers
    log "Stopping Docker containers and cleaning volumes..."
    
    # Stop Mimir containers first
    if [ -f "docker-compose.yml" ]; then
        log "Stopping Mimir services..."
        docker compose down --volumes --remove-orphans || true
    fi
    
    # Stop Supabase containers if they exist
    if [ -f "supabase/docker/docker-compose.yml" ]; then
        log "Stopping Supabase services..."
        (cd supabase/docker && docker compose down --volumes --remove-orphans) || true
    fi
    
    # Give Docker a moment to release file handles
    sleep 2
    
    # Clean up any remaining Docker resources
    log "Cleaning up Docker resources..."
    docker system prune -f > /dev/null 2>&1 || true
    
    # Give the system a moment to release all resources
    sleep 1

    # Remove directories and files
    for item in "${items_to_remove[@]}"; do
        local full_path="$ROOT_DIR/$item"
        if [ -e "$full_path" ]; then
            log "Cleaning: $full_path"
            clean_directory "$full_path" 0  # 0 means don't preserve .gitkeep
        else
            log "Path does not exist, skipping: $full_path"
        fi
    done

    # Clean directories and recreate .gitkeep
    for dir in "${dirs_with_gitkeep[@]}"; do
        clean_directory "$ROOT_DIR/$dir" 1
    done

    echo -e "\n${GREEN}${BOLD}Environment reset complete!${NC}"
    echo -e "You can now run ${YELLOW}mimir init${NC} to reinitialize the environment."
    return 0
}

# Run reset function
reset_environment

log "Script completed"
