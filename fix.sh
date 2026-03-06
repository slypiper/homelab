#!/bin/bash

# Source shflags
source /data/linux/lib/shflags/shflags

IFS= read -r -d '' HEADER <<'EOF'
 _____ _      _____ _     _     __  __            _     _            
|  ___(_)_  _|_   _| |__ (_)___|  \/  | __ _  ___| |__ (_)_ __   ___ 
| |_  | \ \/ / | | | '_ \| / __| |\/| |/ _` |/ __| '_ \| | '_ \ / _ \
|  _| | |>  <  | | | | | | \__ \ |  | | (_| | (__| | | | | | | |  __/
|_|   |_/_/\_\ |_| |_| |_|_|___/_|  |_|\__,_|\___|_| |_|_|_| |_|\___|
EOF


# Define Flags
DEFINE_boolean 'header' 'true' 'Show header'
DEFINE_boolean 'quiet' 'false' 'Suppress all optional output' 'q'
DEFINE_boolean 'apply' 'false' 'Apply fixes automatically' 'a'

DEFINE_boolean 'summary' 'true' 'Display a summary of changes'
DEFINE_boolean 'security_updates' 'false' 'Show Ubuntu ESM/Pro security updates'

DEFINE_boolean 'success' 'true' 'Show success messages'
DEFINE_boolean 'warning' 'true' 'Show warning messages'
DEFINE_boolean 'info' 'true' 'Show info messages'
DEFINE_boolean 'debug' 'false' 'Show debug messages' 'd'


# Parse command line arguments
FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

# Handle quiet mode overrides
if [ "${FLAGS_quiet}" -eq "${FLAGS_TRUE}" ]; then
    FLAGS_success="${FLAGS_FALSE}"
    FLAGS_warning="${FLAGS_FALSE}"
    FLAGS_info="${FLAGS_FALSE}"
    FLAGS_debug="${FLAGS_FALSE}"
    FLAGS_header="${FLAGS_FALSE}"
fi

# Source Common Library
MODULE_DIR="/data/github/homelab/fix-modules"
source "${MODULE_DIR}/common.sh"

# Global State
FIX_COMMANDS=()

declare -A OS_INFO
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_INFO[NAME]=$NAME
    OS_INFO[ID]=$ID
    OS_INFO[VERSION]=$VERSION
else
    OS_INFO[NAME]=$(uname -s)
    OS_INFO[ID]="unknown"
    OS_INFO[VERSION]=$(uname -r)
fi

if [ "${FLAGS_header}" -eq "${FLAGS_TRUE}" ]; then
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        clear
        figlet "FixThisMachine" | lolcat
        echo
    else
        clear
        echo
        echo "${HEADER}"
        echo
    fi
fi

printf_info "System" "${OS_INFO[NAME]} ${OS_INFO[VERSION]}"

PARALLEL_MODE=true
MODULE_PIDS=()
MODULE_NAMES=()

load_module() {
    local name=$1
    shift
    local module_file="${MODULE_DIR}/${name}.sh"
    
    if [ ! -f "$module_file" ]; then
        printf_error "MISSING" "Module ${name} not found"
        return
    fi

    (
        source "$module_file"
        FIX_COMMANDS=()
        fix_module "$@" > "/tmp/fix_out_${name}" 2>&1
        for fix in "${FIX_COMMANDS[@]}"; do echo "$fix"; done > "/tmp/fix_fixes_${name}"
    ) &
    MODULE_PIDS+=($!)
    MODULE_NAMES+=("${name^}")
}

for module in "${MODULE_DIR}"/*.sh; do
    name=$(basename "$module" .sh)
    if [[ "$name" != "common" ]]; then
        load_module "$name"
    fi
done

PASSED=0
WARNINGS=0
ERRORS=0

handle_module_done() {
    local name=$1
    local out_file="/tmp/fix_out_${name,,}"
    local fix_file="/tmp/fix_fixes_${name,,}"

    if [ -f "$out_file" ]; then
        grep -Fq "${SUCCESS_ICON}" "$out_file" && ((PASSED++))
        grep -Fq "${WARNING_ICON}" "$out_file" && ((WARNINGS++))
        grep -Fq "${ERROR_ICON}" "$out_file" && ((ERRORS++))
        
        cat "$out_file"
        rm "$out_file"
    fi

    if [ -f "$fix_file" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && FIX_COMMANDS+=("$line")
        done < "$fix_file"
        rm "$fix_file"
    fi
    printf_debug "Core" "Module ${name} finished."
}

spinner "Checking system" handle_module_done

if [[ "${FLAGS_summary}" == "${FLAGS_TRUE}" ]]; then
    if [[ "${FLAGS_info}" == "${FLAGS_TRUE}" ]]; then
        SUMMARY_STATS=""
        [ $PASSED -gt 0 ] && SUMMARY_STATS+="${GREEN}${PASSED} passed${RESET}, "
        [ $WARNINGS -gt 0 ] && SUMMARY_STATS+="${YELLOW}${WARNINGS} warnings${RESET}, "
        [ $ERRORS -gt 0 ] && SUMMARY_STATS+="${RED}${ERRORS} errors${RESET}, "
        
        printf "\n"
        printf_simple "" "Checks complete. ${BOLD}${SUMMARY_STATS%, }${RESET}"
    fi
fi

if [ ${#FIX_COMMANDS[@]} -gt 0 ]; then
    if [ "${FLAGS_quiet}" -eq "${FLAGS_TRUE}" ]; then
        exit 1
    fi

    printf "\n"
    printf_simple "PENDING" "Proposed fixes found:"

    for cmd in "${FIX_COMMANDS[@]}"; do
        printf_simple "" "  ➜ ${cmd}"
    done
    
    if confirm "Apply these fixes?"; then
        for cmd in "${FIX_COMMANDS[@]}"; do
            printf_simple "RUNNING" "${cmd}" "" "${CYAN}"
            eval "$cmd"
            if [ $? -eq 0 ]; then
                printf_success "SUCCESS" "Command returned success response."
            else
                printf_error "FAILURE" "Failed with exit code $?."
            fi
        done
        printf_success "DONE" "All targeted fixes attempted."
    else
        printf_warning "SKIPPED" "Fixes skipped by user."
    fi
fi
