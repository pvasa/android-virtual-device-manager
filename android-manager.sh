#!/usr/bin/env bash

# Android Virtual Device Manager
# A script to manage Android Virtual Devices (AVDs)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Android SDK is installed
check_android_sdk() {
    if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
        echo -e "${RED}Error: ANDROID_HOME or ANDROID_SDK_ROOT environment variable is not set${NC}"
        echo "Please set one of these variables to your Android SDK location"
        exit 1
    fi
    
    local sdk_path="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
    
    if [ ! -d "$sdk_path" ]; then
        echo -e "${RED}Error: Android SDK not found at: $sdk_path${NC}"
        exit 1
    fi
    
    # Check for avdmanager
    if ! command -v avdmanager &> /dev/null; then
        echo -e "${RED}Error: avdmanager not found in PATH${NC}"
        echo "Please ensure Android SDK command-line tools are installed"
        exit 1
    fi
    
    # Check for emulator
    if ! command -v emulator &> /dev/null; then
        echo -e "${RED}Error: emulator not found in PATH${NC}"
        echo "Please ensure Android Emulator is installed"
        exit 1
    fi
}

# Display help message
show_help() {
    cat << EOF
${BLUE}Android Virtual Device Manager${NC}

${GREEN}Usage:${NC}
    $(basename "$0") <command> [options]

${GREEN}Commands:${NC}
    list                    List all available AVDs
    create                  Create a new AVD
    start <avd-name>        Start an AVD
    stop <avd-name>         Stop a running AVD
    delete <avd-name>       Delete an AVD
    info <avd-name>         Show detailed information about an AVD
    packages                List available system images and packages
    help                    Show this help message

${GREEN}Examples:${NC}
    $(basename "$0") list
    $(basename "$0") create
    $(basename "$0") start Pixel_5_API_33
    $(basename "$0") stop Pixel_5_API_33
    $(basename "$0") delete Pixel_5_API_33
    $(basename "$0") info Pixel_5_API_33
    $(basename "$0") packages

${GREEN}Notes:${NC}
    - ANDROID_HOME or ANDROID_SDK_ROOT environment variable must be set
    - Android SDK command-line tools must be installed
    - Android Emulator must be installed

EOF
}

# List all available AVDs
list_avds() {
    echo -e "${BLUE}Available Android Virtual Devices:${NC}"
    echo ""
    avdmanager list avd
}

# Create a new AVD
create_avd() {
    echo -e "${BLUE}Create a new Android Virtual Device${NC}"
    echo ""
    
    # List available system images
    echo -e "${YELLOW}Available system images:${NC}"
    sdkmanager --list 2>/dev/null | grep "system-images" | grep -v "Installed" | head -20
    echo ""
    
    # Prompt for AVD name
    read -p "Enter AVD name: " avd_name
    if [ -z "$avd_name" ]; then
        echo -e "${RED}Error: AVD name cannot be empty${NC}"
        return 1
    fi
    
    # Check if AVD already exists
    if avdmanager list avd | grep -q "Name: $avd_name"; then
        echo -e "${RED}Error: AVD '$avd_name' already exists${NC}"
        return 1
    fi
    
    # Prompt for package
    read -p "Enter system image package (e.g., system-images;android-33;google_apis;x86_64): " package
    if [ -z "$package" ]; then
        echo -e "${RED}Error: Package cannot be empty${NC}"
        return 1
    fi
    
    # Prompt for device type
    echo -e "${YELLOW}Available device types:${NC}"
    avdmanager list device | grep "id:" | head -10
    echo ""
    read -p "Enter device type (e.g., pixel_5) [default: pixel]: " device
    device="${device:-pixel}"
    
    # Create the AVD
    echo -e "${YELLOW}Creating AVD '$avd_name'...${NC}"
    echo "no" | avdmanager create avd -n "$avd_name" -k "$package" -d "$device"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully created AVD '$avd_name'${NC}"
    else
        echo -e "${RED}Failed to create AVD '$avd_name'${NC}"
        return 1
    fi
}

# Start an AVD
start_avd() {
    local avd_name="$1"
    
    if [ -z "$avd_name" ]; then
        echo -e "${RED}Error: AVD name is required${NC}"
        echo "Usage: $(basename "$0") start <avd-name>"
        return 1
    fi
    
    # Check if AVD exists
    if ! avdmanager list avd | grep -q "Name: $avd_name"; then
        echo -e "${RED}Error: AVD '$avd_name' not found${NC}"
        echo "Use '$(basename "$0") list' to see available AVDs"
        return 1
    fi
    
    echo -e "${YELLOW}Starting AVD '$avd_name'...${NC}"
    emulator -avd "$avd_name" &
    
    echo -e "${GREEN}AVD '$avd_name' is starting in the background${NC}"
    echo "PID: $!"
}

# Stop a running AVD
stop_avd() {
    local avd_name="$1"
    
    if [ -z "$avd_name" ]; then
        echo -e "${RED}Error: AVD name is required${NC}"
        echo "Usage: $(basename "$0") stop <avd-name>"
        return 1
    fi
    
    echo -e "${YELLOW}Stopping AVD '$avd_name'...${NC}"
    
    # Find the emulator process
    local pids=$(pgrep -f "emulator.*-avd $avd_name")
    
    if [ -z "$pids" ]; then
        echo -e "${YELLOW}No running instance of AVD '$avd_name' found${NC}"
        return 0
    fi
    
    # Kill the emulator process
    for pid in $pids; do
        kill "$pid" 2>/dev/null && echo -e "${GREEN}Stopped emulator process (PID: $pid)${NC}"
    done
}

# Delete an AVD
delete_avd() {
    local avd_name="$1"
    
    if [ -z "$avd_name" ]; then
        echo -e "${RED}Error: AVD name is required${NC}"
        echo "Usage: $(basename "$0") delete <avd-name>"
        return 1
    fi
    
    # Check if AVD exists
    if ! avdmanager list avd | grep -q "Name: $avd_name"; then
        echo -e "${RED}Error: AVD '$avd_name' not found${NC}"
        return 1
    fi
    
    # Confirm deletion
    read -p "Are you sure you want to delete AVD '$avd_name'? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Deletion cancelled${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Deleting AVD '$avd_name'...${NC}"
    avdmanager delete avd -n "$avd_name"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully deleted AVD '$avd_name'${NC}"
    else
        echo -e "${RED}Failed to delete AVD '$avd_name'${NC}"
        return 1
    fi
}

# Show AVD information
show_avd_info() {
    local avd_name="$1"
    
    if [ -z "$avd_name" ]; then
        echo -e "${RED}Error: AVD name is required${NC}"
        echo "Usage: $(basename "$0") info <avd-name>"
        return 1
    fi
    
    # Check if AVD exists
    if ! avdmanager list avd | grep -q "Name: $avd_name"; then
        echo -e "${RED}Error: AVD '$avd_name' not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}AVD Information: $avd_name${NC}"
    echo ""
    avdmanager list avd | sed -n "/Name: $avd_name/,/---/p"
    
    # Check if AVD is running
    if pgrep -f "emulator.*-avd $avd_name" > /dev/null; then
        echo -e "${GREEN}Status: Running${NC}"
    else
        echo -e "${YELLOW}Status: Stopped${NC}"
    fi
}

# List available packages
list_packages() {
    echo -e "${BLUE}Available System Images and Packages:${NC}"
    echo ""
    echo -e "${YELLOW}Fetching package list (this may take a moment)...${NC}"
    echo ""
    sdkmanager --list 2>/dev/null | grep "system-images"
}

# Main function
main() {
    # Check for Android SDK before processing commands
    if [ "$1" != "help" ] && [ "$1" != "-h" ] && [ "$1" != "--help" ] && [ -n "$1" ]; then
        check_android_sdk
    fi
    
    case "${1:-help}" in
        list)
            list_avds
            ;;
        create)
            create_avd
            ;;
        start)
            start_avd "$2"
            ;;
        stop)
            stop_avd "$2"
            ;;
        delete)
            delete_avd "$2"
            ;;
        info)
            show_avd_info "$2"
            ;;
        packages)
            list_packages
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$1'${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
