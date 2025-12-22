#!/bin/bash

# ==============================================================================
# 🤖 Android Emulator Manager
# ==============================================================================

# --- Visual Styling ---
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- Configuration & Persistence ---
CONFIG_FILE="$HOME/.android_manager_config"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        CMD_TOOLS_VER="13114758"
        DEFAULT_API="35"
        save_config
    fi
}

save_config() {
    echo "CMD_TOOLS_VER=\"$CMD_TOOLS_VER\"" > "$CONFIG_FILE"
    echo "DEFAULT_API=\"$DEFAULT_API\"" >> "$CONFIG_FILE"
}

# --- Environment Detection ---

detect_os_and_paths() {
    case "$(uname -s)" in
        Darwin*)    
            OS_TYPE="macOS"
            DEFAULT_SDK_LOC="$HOME/Library/Android/sdk"
            ;;
        Linux*)     
            OS_TYPE="Linux"
            DEFAULT_SDK_LOC="$HOME/Android/Sdk"
            ;;
        *)          
            echo "Unsupported OS"; exit 1 
            ;;
    esac

    if [ -z "$ANDROID_HOME" ]; then
        export ANDROID_HOME="$DEFAULT_SDK_LOC"
    fi
    
    CMD_LINE_TOOLS_ROOT="$ANDROID_HOME/cmdline-tools/latest"
    SDK_MANAGER="$CMD_LINE_TOOLS_ROOT/bin/sdkmanager"
    AVD_MANAGER="$CMD_LINE_TOOLS_ROOT/bin/avdmanager"
    EMULATOR="$ANDROID_HOME/emulator/emulator"
    ADB="$ANDROID_HOME/platform-tools/adb"
    
    if [[ "$(uname -m)" == "arm64" ]]; then 
        ABI="arm64-v8a"
    else 
        ABI="x86_64"
    fi

    if [ -z "$JAVA_HOME" ]; then
        if command -v java >/dev/null; then
            if [ "$OS_TYPE" == "macOS" ]; then
                export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null)
            else
                export JAVA_HOME=$(dirname $(dirname $(readlink -f $(command -v java))))
            fi
        fi
    fi
}

cleanup() { tput cnorm; echo ""; exit 0; }
trap cleanup EXIT INT TERM

# --- Utility Functions ---

print_header() { echo -e "  ${BLUE}ℹ${NC}  $1"; }
print_success() { echo -e "  ${GREEN}✔${NC}  $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
print_err() { echo -e "  ${RED}✖${NC}  $1"; }
print_step() { echo -e "\n${BOLD}${MAGENTA}:: $1${NC}"; }
pause() { echo ""; read -n 1 -s -r -p "  Press any key to return..."; }

check_dependencies() {
    local missing=0
    for cmd in java curl unzip git; do
        if ! command -v $cmd &> /dev/null; then
            print_err "Missing dependency: $cmd"; missing=1
        fi
    done
    if [ $missing -eq 1 ]; then echo "Please install missing tools."; exit 1; fi
}

get_system_status() {
    if [ -f "$ADB" ]; then
        ACTIVE_COUNT=$("$ADB" devices | grep "emulator-" | grep "device$" | wc -l | xargs)
    else
        ACTIVE_COUNT=0
    fi
    if [ "$ACTIVE_COUNT" -gt 0 ]; then
        EMU_STATUS="${GREEN}Online ($ACTIVE_COUNT active) 🟢${NC}"
    else
        EMU_STATUS="${DIM}Offline ⚪${NC}"
    fi
}

check_first_run() {
    if [ ! -d "$ANDROID_HOME" ] || [ ! -f "$AVD_MANAGER" ]; then
        clear
        echo -e "\n  ${YELLOW}⚠  Android SDK not found${NC}"
        echo -ne "  Enter custom path (or Enter to install): "
        read custom_path
        if [ -n "$custom_path" ]; then
            export ANDROID_HOME="$custom_path"
            CMD_LINE_TOOLS_ROOT="$ANDROID_HOME/cmdline-tools/latest"
            SDK_MANAGER="$CMD_LINE_TOOLS_ROOT/bin/sdkmanager"
            AVD_MANAGER="$CMD_LINE_TOOLS_ROOT/bin/avdmanager"
            EMULATOR="$ANDROID_HOME/emulator/emulator"
            ADB="$ANDROID_HOME/platform-tools/adb"
            if [ -f "$AVD_MANAGER" ]; then return; fi
        fi
        install_sdk; detect_os_and_paths
    fi

    local avd_list=$("$AVD_MANAGER" list avd -c 2>/dev/null)
    if [ -z "$avd_list" ]; then
        clear; echo -e "\n  ${YELLOW}⚠  No Emulators Found${NC}"
        sleep 1; create_new_device
    fi
}

# --- Selection Logic ---

select_avd_interactive() {
    local prompt_text=$1; local mode=$2
    tput cnorm
    EXISTING_AVDS=$("$AVD_MANAGER" list avd -c)
    if [ -z "$EXISTING_AVDS" ]; then print_warn "No emulators found."; tput civis; return 1; fi
    IFS=$'\n' read -rd '' -a avd_list <<< "$EXISTING_AVDS"

    echo -e "  ${DIM}┌───────────────────────────────────────┐${NC}"
    count=1
    for avd in "${avd_list[@]}"; do
        printf "  ${DIM}│${NC} [${BOLD}%s${NC}] %-31s ${DIM}│${NC}\n" "$count" "$avd"
        ((count++))
    done
    echo -e "  ${DIM}└───────────────────────────────────────┘${NC}"
    
    read -p "  $prompt_text: " input_str
    tput civis
    if [[ -z "$input_str" ]] || [[ "$input_str" == "0" ]]; then return 1; fi

    SELECTED_AVDS=()
    IFS=' ' read -r -a selections <<< "$input_str"
    for sel in "${selections[@]}"; do
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#avd_list[@]} ]; then
            SELECTED_AVDS+=("${avd_list[$((sel-1))]}")
        else
            if [ "$mode" == "single" ] && [ ${#selections[@]} -gt 1 ]; then print_err "Select one."; return 1; fi
        fi
    done
    if [ ${#SELECTED_AVDS[@]} -eq 0 ]; then return 1; fi
    return 0
}

select_running_device() {
    local devices=$("$ADB" devices | grep -v "List" | grep -w "device$" | cut -f1)
    if [ -z "$devices" ]; then print_err "No running devices."; return 1; fi
    local device_list=($devices)
    if [ "${#device_list[@]}" -eq 1 ]; then SELECTED_DEVICE="${device_list[0]}"; return 0; fi

    tput cnorm
    echo -e "  ${DIM}┌───────────────────────────────────────┐${NC}"
    local count=1
    for dev in "${device_list[@]}"; do
        local model=$("$ADB" -s "$dev" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        if [ -z "$model" ]; then model="Unknown"; fi
        printf "  ${DIM}│${NC} [${BOLD}%s${NC}] %-16s ${CYAN}%-14s${NC} ${DIM}│${NC}\n" "$count" "$dev" "(${model:0:14})"
        ((count++))
    done
    echo -e "  ${DIM}└───────────────────────────────────────┘${NC}"
    read -p "  Select Target: " sel; tput civis
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#device_list[@]} ]; then
        SELECTED_DEVICE="${device_list[$((sel-1))]}"
        return 0
    fi
    return 1
}

# --- Skin Detection Logic (New Feature) ---

find_and_configure_skin() {
    local config_path="$1"
    local device_name="$2"  # e.g., "pixel_6"
    local api="$3"
    local tag="$4" # google_apis

    echo -e "  ${DIM}Searching for skin frame...${NC}"

    # 1. Normalize device name (Pixel 6 -> pixel_6)
    local safe_name=$(echo "$device_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    
    # 2. Possible skin locations in SDK
    local possible_paths=(
        "$ANDROID_HOME/skins/$safe_name"
        "$ANDROID_HOME/platforms/android-$api/skins/$safe_name"
        "$ANDROID_HOME/system-images/android-$api/$tag/$ABI/skins/$safe_name"
        # Fallbacks for common resolutions if specific device skin is missing
        "$ANDROID_HOME/platforms/android-$api/skins/HVGA"
        "$ANDROID_HOME/skins/HVGA"
    )

    local found_skin=""
    for p in "${possible_paths[@]}"; do
        if [ -d "$p" ]; then
            found_skin="$p"
            break
        fi
    done

    # 3. Write to config
    if [ -n "$found_skin" ]; then
        local skin_name=$(basename "$found_skin")
        echo -e "     ${GREEN}Found skin: $skin_name${NC}"
        {
            echo "skin.name=$skin_name"
            echo "skin.path=$found_skin"
            echo "skin.dynamic=no" # Force static skin
            echo "showDeviceFrame=yes"
        } >> "$config_path"
    else
        echo -e "     ${YELLOW}No matching skin found. Using dynamic frame.${NC}"
        {
            echo "skin.dynamic=yes"
            echo "showDeviceFrame=yes"
        } >> "$config_path"
    fi
}

# --- Core Features ---

install_sdk() {
    tput cnorm
    while true; do
        print_step "Installing Android SDK Tools..."
        if [ ! -f "$SDK_MANAGER" ]; then
            print_header "Downloading Command Line Tools (v${CMD_TOOLS_VER})..."
            local tools_url="https://dl.google.com/android/repository/commandlinetools-mac-${CMD_TOOLS_VER}_latest.zip"
            if [ "$OS_TYPE" == "Linux" ]; then tools_url="https://dl.google.com/android/repository/commandlinetools-linux-${CMD_TOOLS_VER}_latest.zip"; fi
            
            if curl -L --fail -o tools.zip "$tools_url"; then
                 unzip -q tools.zip -d temp_sdk
                 mkdir -p "$ANDROID_HOME/cmdline-tools"
                 mv temp_sdk/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
                 rm -rf temp_sdk tools.zip; break
            else
                 print_err "Download failed."
                 read -p "  Enter new version ID or 'q': " new_ver
                 if [[ "$new_ver" == "q" ]]; then exit 1; fi
                 if [[ -n "$new_ver" ]]; then CMD_TOOLS_VER="$new_ver"; save_config; fi
            fi
        else break; fi
    done
    print_header "Updating SDK Components..."
    yes | "$SDK_MANAGER" --licenses > /dev/null 2>&1
    "$SDK_MANAGER" "platform-tools" "emulator" "platforms;android-$DEFAULT_API" "system-images;android-$DEFAULT_API;google_apis;${ABI}"
    print_success "SDK Ready."; pause; tput civis
}

create_new_device() {
    print_step "Create New Device Wizard"
    tput cnorm
    
    # 1. Hardware
    echo -e "  ${BOLD}1. Select Hardware Profile${NC}"
    AVAILABLE_DEVICES=$("$AVD_MANAGER" list device -c | grep "pixel" | grep -v "watch" | sort -r | head -n 10)
    IFS=$'\n' read -rd '' -a dev_arr <<< "$AVAILABLE_DEVICES"
    count=1
    for device in "${dev_arr[@]}"; do echo -e "     [$count] $device"; ((count++)); done
    read -p "  Select Profile [1]: " sel; sel="${sel:-1}" 
    if ! [[ "$sel" =~ ^[0-9]+$ ]]; then sel=1; fi
    CHOSEN_ID="${dev_arr[$((sel-1))]}"
    
    # 2. Image Type
    echo -e "\n  ${BOLD}2. Image Type${NC}"
    echo -e "     [1] Standard (Root capable)"
    echo -e "     [2] Play Store (No Root)"
    read -p "  Select Type [1]: " type_sel
    local tag="google_apis"; local tag_display="API"
    if [ "$type_sel" == "2" ]; then tag="google_apis_playstore"; tag_display="PlayStore"; fi

    # 3. API Level
    echo -e "\n  ${BOLD}3. Android Version${NC}"
    INSTALLED_IMGS=$("$SDK_MANAGER" --list_installed 2>/dev/null | grep "system-images" | grep "$tag" | grep "$ABI")
    apis=()
    if [ -n "$INSTALLED_IMGS" ]; then
        raw_list=$(echo "$INSTALLED_IMGS" | grep -o 'android-[0-9]*' | sort -V -r | uniq)
        while read -r line; do [[ -n "$line" ]] && apis+=("$line"); done <<< "$raw_list"
        count=1
        for api in "${apis[@]}"; do echo -e "     [$count] API ${api#android-} (Installed)"; ((count++)); done
    fi
    echo -e "     [0] Download New (Default: API $DEFAULT_API)"
    read -p "  Select API [1]: " api_sel; api_sel="${api_sel:-1}"
    if [ "$api_sel" == "0" ]; then API_CHOICE="$DEFAULT_API"
    elif [[ "$api_sel" =~ ^[0-9]+$ ]] && [ "$api_sel" -le ${#apis[@]} ]; then
         raw="${apis[$((api_sel-1))]}"; API_CHOICE="${raw#android-}"
    else API_CHOICE="$DEFAULT_API"; fi

    # 4. Config
    echo -e "\n  ${BOLD}4. Specs${NC}"
    read -p "  RAM (MB) [4096]: " input_ram; RAM_SIZE=$(echo "$input_ram" | tr -cd '0-9'); RAM_SIZE="${RAM_SIZE:-4096}"
    read -p "  Storage (MB) [8192]: " input_storage; STORAGE_SIZE=$(echo "$input_storage" | tr -cd '0-9'); STORAGE_SIZE="${STORAGE_SIZE:-8192}"

    AVD_NAME="${CHOSEN_ID// /_}_${tag_display}_API${API_CHOICE}"
    echo -e "\n  ${DIM}Creating: $AVD_NAME${NC}"
    read -p "  Confirm? (Y/n): " confirm; confirm="${confirm:-y}"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then return; fi

    print_header "Checking System Image..."
    IMAGE_PKG="system-images;android-${API_CHOICE};${tag};${ABI}"
    if ! "$SDK_MANAGER" --list_installed | grep -q "$IMAGE_PKG"; then
        print_warn "Downloading image..."
        echo "y" | "$SDK_MANAGER" "$IMAGE_PKG"
    fi

    print_header "Creating AVD..."
    echo "no" | "$AVD_MANAGER" create avd -n "$AVD_NAME" -k "$IMAGE_PKG" --device "$CHOSEN_ID" --force > /dev/null
    
    CONFIG="$HOME/.android/avd/$AVD_NAME.avd/config.ini"
    if [ -f "$CONFIG" ]; then
        { 
            echo "hw.ramSize=$RAM_SIZE"
            echo "disk.dataPartition.size=${STORAGE_SIZE}M"
            echo "hw.gpu.enabled=yes"
        } >> "$CONFIG"
        
        # INJECT SKIN SETTINGS
        find_and_configure_skin "$CONFIG" "$CHOSEN_ID" "$API_CHOICE" "$tag"
    fi
    
    print_success "Device created."; pause; tput civis
}

launch_detached() {
    print_step "Launch Emulator"
    if select_avd_interactive "Select Device" "single"; then
        target="${SELECTED_AVDS[0]}"
        echo -e "\n  ${WHITE}[1]${NC} Quick Boot"
        echo -e "  ${WHITE}[2]${NC} Cold Boot"
        echo -ne "  Select mode [1]: "
        read -r mode_sel
        local boot_flag=""
        if [ "$mode_sel" == "2" ]; then boot_flag="-no-snapshot-load"; fi
        print_header "Launching..."
        nohup "$EMULATOR" -avd "$target" -gpu auto $boot_flag > /dev/null 2>&1 & disown
        print_success "Launched background process."; sleep 2
    fi
}

record_video() {
    print_step "Record Video"
    if ! select_running_device; then pause; return; fi
    local filename="video_$(date +%Y%m%d_%H%M%S).mp4"
    tput cnorm
    print_header "Recording... (Press ENTER to Stop)"
    "$ADB" -s "$SELECTED_DEVICE" shell screenrecord "/sdcard/temp_rec.mp4" &
    ADB_PID=$!
    read -r _
    kill "$ADB_PID" 2>/dev/null
    "$ADB" -s "$SELECTED_DEVICE" shell pkill -2 screenrecord
    
    print_header "Processing..."
    local retries=0
    while [ $retries -lt 20 ]; do
        if ! "$ADB" -s "$SELECTED_DEVICE" shell pgrep screenrecord > /dev/null; then break; fi
        sleep 0.5; ((retries++))
    done
    "$ADB" -s "$SELECTED_DEVICE" pull "/sdcard/temp_rec.mp4" "$filename" > /dev/null
    "$ADB" -s "$SELECTED_DEVICE" shell rm "/sdcard/temp_rec.mp4"
    if [ -f "$filename" ]; then print_success "Saved: $PWD/$filename"; if [ "$OS_TYPE" == "macOS" ]; then open -R "$filename"; fi; else print_err "Failed."; fi
    tput civis; pause
}

pair_wireless() {
    print_step "ADB Wireless Pairing"
    tput cnorm; echo -e "  ${DIM}Dev Options > Wireless Debugging > Pair with Code${NC}"
    read -p "  IP:Port: " ip_port
    read -p "  Code: " code
    if [ -n "$ip_port" ] && [ -n "$code" ]; then
        "$ADB" pair "$ip_port" "$code"
        print_success "Pairing sent. Run 'adb connect IP:PORT' if needed."
    fi
    pause; tput civis
}

stop_specific() {
    print_step "Stop Device"
    if select_running_device; then
        "$ADB" -s "$SELECTED_DEVICE" emu kill
        print_success "Stopped."; sleep 1
    fi
}

view_logs() {
    print_step "Logcat"
    if ! select_running_device; then pause; return; fi
    tput cnorm
    echo -e "  ${WHITE}[1]${NC} All Error Logs"
    echo -e "  ${WHITE}[2]${NC} Filter by App"
    read -p "  Mode [1]: " mode
    trap 'return' INT
    if [ "$mode" == "2" ]; then
        read -p "  Package: " pkg
        pid=$("$ADB" -s "$SELECTED_DEVICE" shell pidof -s "$pkg")
        if [ -n "$pid" ]; then "$ADB" -s "$SELECTED_DEVICE" logcat --pid="$pid" -v color; else print_err "App not running."; fi
    else "$ADB" -s "$SELECTED_DEVICE" logcat -v color *:E; fi
    trap cleanup INT; tput civis; pause
}

install_apk() {
    print_step "Install APK"
    if ! select_running_device; then pause; return; fi
    tput cnorm; read -e -r -p "  Path: " apk_path
    apk_path="${apk_path%\"}"; apk_path="${apk_path#\"}"
    if [ -f "$apk_path" ]; then "$ADB" -s "$SELECTED_DEVICE" install -r "$apk_path" && print_success "Installed."; else print_err "Not found."; fi
    pause; tput civis
}

# --- Menus ---

toolbox_menu() {
    while true; do
        clear; echo -e "\n  ${BOLD}${YELLOW}🛠  TOOLBOX${NC}"; echo -e "  ${DIM}──────────────────────────────${NC}"
        echo -e "  ${WHITE}[1]${NC} Wipe Data"; echo -e "  ${WHITE}[2]${NC} Stop Device"; echo -e "  ${WHITE}[3]${NC} Delete Device"; echo -e "  ${WHITE}[4]${NC} Kill All"; echo -e "  ${WHITE}[0]${NC} Back"
        read -s -n 1 key
        case $key in
            1) if select_avd_interactive "Select" "single"; then "$EMULATOR" -avd "${SELECTED_AVDS[0]}" -wipe-data > /dev/null 2>&1 & disown; print_success "Launched."; fi ;;
            2) stop_specific ;;
            3) if select_avd_interactive "Delete" "multi"; then for avd in "${SELECTED_AVDS[@]}"; do "$AVD_MANAGER" delete avd -n "$avd"; done; print_success "Deleted."; fi ;;
            4) pkill -f "qemu-system"; print_success "Stopped all."; sleep 1 ;;
            0|$'\e') return ;;
        esac
    done
}

dev_menu() {
    while true; do
        clear; echo -e "\n  ${BOLD}${CYAN}💻  DEV TOOLS${NC}"; echo -e "  ${DIM}──────────────────────────────${NC}"
        echo -e "  ${WHITE}[1]${NC} Logs"; echo -e "  ${WHITE}[2]${NC} Video"; echo -e "  ${WHITE}[3]${NC} Wireless Pair"; echo -e "  ${WHITE}[4]${NC} Install APK"; echo -e "  ${WHITE}[0]${NC} Back"
        read -s -n 1 key
        case $key in 1) view_logs ;; 2) record_video ;; 3) pair_wireless ;; 4) install_apk ;; 0|$'\e') return ;; esac
    done
}

# --- Main ---
load_config; detect_os_and_paths; check_dependencies; check_first_run; tput civis
while true; do
    get_system_status; clear
    echo -e "  ${BLUE}┌──────────────────────────────────────────────┐${NC}"
    echo -e "  ${BLUE}│       ${BOLD}${WHITE}ANDROID EMULATOR MANAGER ${NC}              ${BLUE}│${NC}"
    echo -e "  ${BLUE}└──────────────────────────────────────────────┘${NC}"
    echo -e "   ${DIM}OS:${NC} $OS_TYPE   ${DIM}Status:${NC} $EMU_STATUS"
    echo -e "\n  ${BOLD}MAIN MENU${NC}"
    echo -e "  ${WHITE}[1]${NC} 🚀 Launch Emulator"
    echo -e "  ${WHITE}[2]${NC} 💻 Developer Tools"
    echo -e "  ${WHITE}[3]${NC} 🛠  Toolbox"
    echo -e "  ${WHITE}[4]${NC} 📱 Create New Device"
    echo -e "  ${WHITE}[5]${NC} ⚙  Update SDK"
    echo -e "  ${WHITE}[0]${NC} 👋 Quit"
    echo -e ""
    read -s -n 1 key
    case $key in 1) launch_detached ;; 2) dev_menu ;; 3) toolbox_menu ;; 4) create_new_device ;; 5) install_sdk ;; 0|q|$'\e') cleanup ;; esac
done
