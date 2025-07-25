#!/bin/bash
#
# User Management Script (Improved Version)
# -------------------------------------------------------------------------
# Description: Creates a new user account with proper validation and setup
# Usage: ./User.sh <username> [options]
# Options:
#   --groups <group1,group2>  Add user to specified groups
#   --shell <shell_path>      Set custom shell (default: /bin/bash)
#   --comment <comment>       Set user comment/description
#   --no-password             Skip password setup
#   --dry-run                 Show what would be done without executing
# -------------------------------------------------------------------------

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# =========================================================================
# IMPROVED COLOR AND FORMATTING DEFINITIONS
# =========================================================================

# Terminal color codes with descriptive names and additional formatting
declare -A COLORS=(
    # Basic colors
    ["RED"]='\033[0;31m'
    ["GREEN"]='\033[0;32m'
    ["YELLOW"]='\033[0;33m'
    ["BLUE"]='\033[0;34m'
    ["MAGENTA"]='\033[0;35m'
    ["CYAN"]='\033[0;36m'
    ["WHITE"]='\033[0;37m'
    
    # Bright colors for emphasis
    ["BRIGHT_RED"]='\033[1;31m'
    ["BRIGHT_GREEN"]='\033[1;32m'
    ["BRIGHT_YELLOW"]='\033[1;33m'
    ["BRIGHT_BLUE"]='\033[1;34m'
    
    # Background colors for critical messages
    ["BG_RED"]='\033[41m'
    ["BG_GREEN"]='\033[42m'
    ["BG_YELLOW"]='\033[43m'
    
    # Text formatting
    ["BOLD"]='\033[1m'
    ["DIM"]='\033[2m'
    ["UNDERLINE"]='\033[4m'
    ["BLINK"]='\033[5m'
    ["REVERSE"]='\033[7m'
    
    # Reset
    ["NC"]='\033[0m'  # No Color/Reset
)

# Semantic color mapping for better maintainability
declare -A SEMANTIC_COLORS=(
    ["ERROR"]="${COLORS[BRIGHT_RED]}"
    ["SUCCESS"]="${COLORS[BRIGHT_GREEN]}"
    ["WARNING"]="${COLORS[BRIGHT_YELLOW]}"
    ["INFO"]="${COLORS[CYAN]}"
    ["DEBUG"]="${COLORS[DIM]}"
    ["HIGHLIGHT"]="${COLORS[BOLD]}"
    ["CRITICAL"]="${COLORS[BG_RED]}${COLORS[WHITE]}"
)

# Check if terminal supports colors
if [[ ! -t 1 ]] || [[ "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
    # Disable colors for non-interactive terminals or when NO_COLOR is set
    for key in "${!COLORS[@]}"; do
        COLORS["$key"]=""
    done
    for key in "${!SEMANTIC_COLORS[@]}"; do
        SEMANTIC_COLORS["$key"]=""
    done
fi

# =========================================================================
# IMPROVED UTILITY FUNCTIONS
# =========================================================================

# Function: print_colored
# Purpose: Print colored text with semantic meaning
# Parameters:
#   $1 - Message type (ERROR, SUCCESS, WARNING, INFO, DEBUG)
#   $2 - Message text
#   $3 - Optional: suppress newline (use "n" to suppress)
print_colored() {
    local type="$1"
    local message="$2"
    local suppress_newline="${3:-}"
    
    local color="${SEMANTIC_COLORS[$type]:-}"
    local reset="${COLORS[NC]}"
    
    if [[ "$suppress_newline" == "n" ]]; then
        printf "%b%s%b" "$color" "$message" "$reset"
    else
        printf "%b%s%b\n" "$color" "$message" "$reset"
    fi
}

# Function: print_banner
# Purpose: Print a formatted banner with border
print_banner() {
    local message="$1"
    local width=60
    local border=$(printf "%*s" "$width" | tr ' ' '=')
    
    echo
    print_colored "HIGHLIGHT" "$border"
    print_colored "HIGHLIGHT" "$(printf "%*s" $(((width + ${#message}) / 2)) "$message")"
    print_colored "HIGHLIGHT" "$border"
    echo
}

# Function: confirm_action
# Purpose: Ask user for confirmation before proceeding
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    print_colored "WARNING" "$message" "n"
    if [[ "$default" == "y" ]]; then
        print_colored "INFO" " [Y/n]: " "n"
    else
        print_colored "INFO" " [y/N]: " "n"
    fi
    
    read -r response
    response="${response:-$default}"
    
    case "${response,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

# =========================================================================
# CONFIGURATION AND GLOBAL VARIABLES
# =========================================================================

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/user-management"
readonly LOG_FILE="$LOG_DIR/user_management_$(date +%Y%m%d_%H%M%S).log"

# Default values
DEFAULT_SHELL="/bin/bash"
DRY_RUN=false
SKIP_PASSWORD=false
VERBOSE=false

# =========================================================================
# IMPROVED LOGGING SYSTEM
# =========================================================================

# Function: setup_logging
# Purpose: Initialize logging directory and file
setup_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            print_colored "WARNING" "Cannot create log directory $LOG_DIR, using /tmp"
            LOG_FILE="/tmp/user_management_$(date +%Y%m%d_%H%M%S).log"
        }
    fi
    
    touch "$LOG_FILE" 2>/dev/null || {
        print_colored "ERROR" "Cannot create log file, logging to stdout only"
        LOG_FILE="/dev/stdout"
    }
}

# Function: log
# Purpose: Enhanced logging with multiple levels and structured output
# Parameters:
#   $1 - Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
#   $2 - Message to log
#   $3 - Optional: component name
log() {
    local level="$1"
    local message="$2"
    local component="${3:-MAIN}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file (structured format)
    printf "[%s] [%s] [%s] %s\n" "$timestamp" "$level" "$component" "$message" >> "$LOG_FILE"
    
    # Log to terminal with colors (if verbose or not INFO level)
    if [[ "$VERBOSE" == true ]] || [[ "$level" != "INFO" ]]; then
        printf "[%s] " "$timestamp"
        print_colored "$level" "[$level]" "n"
        printf " %s\n" "$message"
    fi
}

# =========================================================================
# VALIDATION FUNCTIONS
# =========================================================================

# Function: check_dependencies
# Purpose: Verify required system commands are available
check_dependencies() {
    local missing_commands=()
    local required_commands=("useradd" "passwd" "id" "getent")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log "ERROR" "Missing required commands: ${missing_commands[*]}"
        print_colored "ERROR" "Missing required commands: ${missing_commands[*]}"
        exit 1
    fi
}

# Function: check_root_privileges
# Purpose: Enhanced root privilege checking with better messaging
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Script requires root privileges"
        print_colored "ERROR" "This script requires root privileges"
        print_colored "INFO" "Please run with: sudo $SCRIPT_NAME $*"
        exit 1
    fi
    log "INFO" "Root privileges confirmed"
}

# Function: validate_username_enhanced
# Purpose: Enhanced username validation with detailed feedback
validate_username_enhanced() {
    local username="$1"
    
    # Check if username is provided
    if [[ -z "$username" ]]; then
        log "ERROR" "No username provided"
        print_colored "ERROR" "No username provided"
        show_usage
        exit 2
    fi
    
    # Check username length
    if [[ ${#username} -gt 32 ]]; then
        log "ERROR" "Username '$username' exceeds maximum length (32 characters)"
        print_colored "ERROR" "Username '$username' is too long (maximum 32 characters)"
        exit 2
    fi
    
    if [[ ${#username} -lt 1 ]]; then
        log "ERROR" "Username cannot be empty"
        print_colored "ERROR" "Username cannot be empty"
        exit 2
    fi
    
    # Check for valid characters (POSIX portable username)
    if [[ ! "$username" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
        log "ERROR" "Username '$username' contains invalid characters"
        print_colored "ERROR" "Invalid username format"
        print_colored "INFO" "Username must:"
        print_colored "INFO" "  - Start with lowercase letter or underscore"
        print_colored "INFO" "  - Contain only lowercase letters, numbers, underscore, or hyphen"
        print_colored "INFO" "  - Be 1-32 characters long"
        exit 2
    fi
    
    # Check for reserved usernames
    local reserved_users=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "systemd-network" "systemd-resolve" "messagebus" "systemd-timesync" "syslog" "_apt" "tss" "uuidd" "tcpdump" "sshd" "landscape" "pollinate" "ec2-instance-connect" "systemd-coredump" "ubuntu" "lxd" "dnsmasq" "libvirt-qemu" "libvirt-dnsmasq")
    
    for reserved in "${reserved_users[@]}"; do
        if [[ "$username" == "$reserved" ]]; then
            log "ERROR" "Username '$username' is reserved"
            print_colored "ERROR" "Username '$username' is reserved by the system"
            exit 2
        fi
    done
    
    # Check if user already exists
    if getent passwd "$username" >/dev/null 2>&1; then
        log "ERROR" "User '$username' already exists"
        print_colored "ERROR" "User '$username' already exists"
        exit 2
    fi
    
    # Check if group with same name exists
    if getent group "$username" >/dev/null 2>&1; then
        log "WARNING" "Group '$username' already exists, will be used as primary group"
        print_colored "WARNING" "Group '$username' already exists and will be used as primary group"
    fi
    
    log "INFO" "Username '$username' validation passed"
    return 0
}

# Function: validate_shell
# Purpose: Validate shell path
validate_shell() {
    local shell="$1"
    
    if [[ ! -f "$shell" ]]; then
        log "ERROR" "Shell '$shell' does not exist"
        print_colored "ERROR" "Shell '$shell' does not exist"
        return 1
    fi
    
    if [[ ! -x "$shell" ]]; then
        log "ERROR" "Shell '$shell' is not executable"
        print_colored "ERROR" "Shell '$shell' is not executable"
        return 1
    fi
    
    # Check if shell is in /etc/shells
    if ! grep -q "^$shell$" /etc/shells 2>/dev/null; then
        log "WARNING" "Shell '$shell' is not listed in /etc/shells"
        print_colored "WARNING" "Shell '$shell' is not listed in /etc/shells"
        if ! confirm_action "Continue anyway?"; then
            return 1
        fi
    fi
    
    return 0
}

# =========================================================================
# USER CREATION FUNCTIONS
# =========================================================================

# Function: create_user_enhanced
# Purpose: Enhanced user creation with better error handling and options
create_user_enhanced() {
    local username="$1"
    local groups="$2"
    local shell="$3"
    local comment="$4"
    
    log "INFO" "Starting user creation process for '$username'"
    print_banner "Creating User: $username"
    
    # Build useradd command
    local useradd_cmd=("useradd")
    
    # Add standard options
    useradd_cmd+=("-m")  # Create home directory
    useradd_cmd+=("-s" "$shell")
    
    # Add optional parameters
    if [[ -n "$groups" ]]; then
        useradd_cmd+=("-G" "$groups")
        log "INFO" "User will be added to groups: $groups"
    fi
    
    if [[ -n "$comment" ]]; then
        useradd_cmd+=("-c" "$comment")
        log "INFO" "User comment set to: $comment"
    fi
    
    # Add username
    useradd_cmd+=("$username")
    
    # Log the command (for debugging)
    log "DEBUG" "Executing command: ${useradd_cmd[*]}"
    
    # Execute command or show what would be done
    if [[ "$DRY_RUN" == true ]]; then
        print_colored "INFO" "DRY RUN: Would execute: ${useradd_cmd[*]}"
        print_colored "INFO" "DRY RUN: Home directory would be created at: $(eval echo ~"$username")"
        return 0
    fi
    
    # Execute the useradd command
    if "${useradd_cmd[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "User '$username' created successfully"
        print_colored "SUCCESS" "✓ User '$username' created successfully"
        
        # Show user information
        local home_dir
        home_dir=$(getent passwd "$username" | cut -d: -f6)
        print_colored "INFO" "Home directory: $home_dir"
        print_colored "INFO" "Shell: $shell"
        
        # Set password unless skipped
        if [[ "$SKIP_PASSWORD" == false ]]; then
            print_colored "INFO" "Setting password for '$username'"
            if ! passwd "$username"; then
                log "WARNING" "Password setting failed or was cancelled"
                print_colored "WARNING" "Password not set - user account may be locked"
            fi
        else
            print_colored "INFO" "Password setup skipped"
            print_colored "WARNING" "User account may be locked until password is set"
        fi
        
        return 0
    else
        local exit_code=$?
        log "ERROR" "Failed to create user '$username' (exit code: $exit_code)"
        print_colored "ERROR" "✗ Failed to create user '$username'"
        exit 3
    fi
}

# =========================================================================
# HELP AND USAGE FUNCTIONS
# =========================================================================

# Function: show_usage
# Purpose: Display usage information with colors
show_usage() {
    print_banner "User Management Script"
    
    print_colored "INFO" "USAGE:"
    echo "  $SCRIPT_NAME <username> [OPTIONS]"
    echo
    
    print_colored "INFO" "OPTIONS:"
    echo "  --groups <group1,group2>   Add user to specified groups"
    echo "  --shell <shell_path>       Set custom shell (default: $DEFAULT_SHELL)"
    echo "  --comment <comment>        Set user comment/description"
    echo "  --no-password             Skip password setup"
    echo "  --dry-run                 Show what would be done without executing"
    echo "  --verbose                 Enable verbose output"
    echo "  --help                    Show this help message"
    echo
    
    print_colored "INFO" "EXAMPLES:"
    echo "  $SCRIPT_NAME john"
    echo "  $SCRIPT_NAME jane --groups sudo,docker --comment 'Jane Doe'"
    echo "  $SCRIPT_NAME admin --shell /bin/zsh --no-password"
    echo "  $SCRIPT_NAME test --dry-run"
    echo
}

# =========================================================================
# MAIN EXECUTION LOGIC
# =========================================================================

# Function: parse_arguments
# Purpose: Parse and validate command line arguments
parse_arguments() {
    local username=""
    local groups=""
    local shell="$DEFAULT_SHELL"
    local comment=""
    
    # Check if any arguments provided
    if [[ $# -eq 0 ]]; then
        log "ERROR" "No arguments provided"
        print_colored "ERROR" "No arguments provided"
        show_usage
        exit 1
    fi
    
    # Get username (first non-option argument)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --groups)
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    groups="$2"
                    shift 2
                else
                    print_colored "ERROR" "--groups requires a value"
                    exit 1
                fi
                ;;
            --shell)
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    shell="$2"
                    shift 2
                else
                    print_colored "ERROR" "--shell requires a value"
                    exit 1
                fi
                ;;
            --comment)
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    comment="$2"
                    shift 2
                else
                    print_colored "ERROR" "--comment requires a value"
                    exit 1
                fi
                ;;
            --no-password)
                SKIP_PASSWORD=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --*)
                log "WARNING" "Unknown option: $1"
                print_colored "WARNING" "Unknown option: $1"
                shift
                ;;
            *)
                if [[ -z "$username" ]]; then
                    username="$1"
                else
                    log "WARNING" "Ignoring extra argument: $1"
                    print_colored "WARNING" "Ignoring extra argument: $1"
                fi
                shift
                ;;
        esac
    done
    
    # Export parsed values
    export PARSED_USERNAME="$username"
    export PARSED_GROUPS="$groups"
    export PARSED_SHELL="$shell"
    export PARSED_COMMENT="$comment"
}

# Function: main
# Purpose: Main execution flow
main() {
    # Initialize logging
    setup_logging
    
    log "INFO" "Starting user management script"
    log "INFO" "Command line: $0 $*"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check system requirements
    check_dependencies
    check_root_privileges
    
    # Validate inputs
    validate_username_enhanced "$PARSED_USERNAME"
    
    if ! validate_shell "$PARSED_SHELL"; then
        exit 2
    fi
    
    # Show configuration summary
    if [[ "$VERBOSE" == true ]] || [[ "$DRY_RUN" == true ]]; then
        print_colored "INFO" "Configuration Summary:"
        print_colored "INFO" "  Username: $PARSED_USERNAME"
        print_colored "INFO" "  Shell: $PARSED_SHELL"
        print_colored "INFO" "  Groups: ${PARSED_GROUPS:-none}"
        print_colored "INFO" "  Comment: ${PARSED_COMMENT:-none}"
        print_colored "INFO" "  Skip password: $SKIP_PASSWORD"
        print_colored "INFO" "  Dry run: $DRY_RUN"
        echo
    fi
    
    # Confirm action for non-dry-run mode
    if [[ "$DRY_RUN" == false ]] && [[ -t 0 ]]; then
        if ! confirm_action "Create user '$PARSED_USERNAME'?" "y"; then
            log "INFO" "User creation cancelled by user"
            print_colored "INFO" "Operation cancelled"
            exit 0
        fi
    fi
    
    # Create the user
    create_user_enhanced "$PARSED_USERNAME" "$PARSED_GROUPS" "$PARSED_SHELL" "$PARSED_COMMENT"
    
    # Final success message
    log "INFO" "User management completed successfully"
    print_colored "SUCCESS" "✓ User management completed successfully"
    
    if [[ "$LOG_FILE" != "/dev/stdout" ]]; then
        print_colored "INFO" "Detailed logs available at: $LOG_FILE"
    fi
}

# =========================================================================
# SCRIPT ENTRY POINT
# =========================================================================

# Trap to ensure clean exit
trap 'log "INFO" "Script interrupted"; exit 130' INT TERM

# Run main function with all arguments
main "$@"
