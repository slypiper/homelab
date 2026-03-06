#!/bin/bash

fix_module() {
    if [[ "${OS_INFO[ID]}" == "ubuntu" ]]; then
        fix_ubuntu
    elif [[ "${OS_INFO[ID]}" == "arch" ]]; then
        fix_arch
    else
        printf_warning "Updates" "Update check not implemented for ${OS_INFO[NAME]}."
    fi
}

fix_ubuntu() {
    do_check() {
        NOTIFIER_FILE="/var/lib/update-notifier/updates-available"
        if [ -f "$NOTIFIER_FILE" ]; then
            CONTENT=$(cat "$NOTIFIER_FILE")
            VAL1=$(echo "$CONTENT" | grep -Po '[0-9]+(?= updates can be applied immediately)' || echo "")
            [ -z "$VAL1" ] && VAL1=$(echo "$CONTENT" | grep -Po '[0-9]+(?= updates can be installed)' || echo "")
            VAL2=$(echo "$CONTENT" | grep -Po '[0-9]+(?= updates are security updates)' || echo "0")
            VAL3=$(echo "$CONTENT" | grep -Po '[0-9]+(?= additional security updates can be applied with ESM)' || echo "0")
            
            if [ -n "$VAL1" ]; then
                echo "SUCCESS|$VAL1|$VAL2|$VAL3"
                return
            fi
        fi

        APT_CHECK=$(timeout 5s apt-get -s upgrade 2>&1)
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then echo "ANOMALOUS|TIMEOUT|0|0"
        elif echo "$APT_CHECK" | grep -q "Could not get lock"; then echo "ANOMALOUS|LOCKED|0|0"
        elif echo "$APT_CHECK" | grep -q "failed to fetch"; then echo "ANOMALOUS|NO_NETWORK|0|0"
        else
            VAL1=$(echo "$APT_CHECK" | grep -P "^\d+ upgraded, \d+ newly installed" | awk '{print $1}')
            if [ -z "$VAL1" ]; then echo "ANOMALOUS|BAD_FORMAT|0|0"
            else echo "SUCCESS|$VAL1|0|0"
            fi
        fi
    }

    RAW=$(do_check)
    TYPE=$(echo "$RAW" | cut -d'|' -f1)
    
    declare -A UPDATES=(
        [STD]=$(echo "$RAW" | cut -d'|' -f2)
        [SEC]=$(echo "$RAW" | cut -d'|' -f3)
        [ESM]=$(echo "$RAW" | cut -d'|' -f4)
    )

    if [ "$TYPE" == "SUCCESS" ]; then
        if [ "${UPDATES[STD]}" -eq 0 ] && { [ "${UPDATES[ESM]}" -eq 0 ] || [ "${FLAGS_security_updates}" -eq "${FLAGS_FALSE}" ]; }; then
            printf_success "Updates" "System is up to date."
        elif [ "${UPDATES[SEC]}" -gt 0 ]; then
            printf_error "Updates" "Found ${UPDATES[STD]} updates (${UPDATES[SEC]} critical security)." "Fix with ${CYAN}sudo apt upgrade${RESET}"
            FIX_COMMANDS+=("sudo apt-get upgrade -y")
        elif [ "${UPDATES[STD]}" -gt 0 ]; then
            printf_warning "Updates" "Found ${UPDATES[STD]} updates requiring attention." "Fix with ${CYAN}sudo apt upgrade${RESET}"
            FIX_COMMANDS+=("sudo apt-get upgrade -y")
        elif [ "${UPDATES[ESM]}" -gt 0 ]; then
            printf_warning "Updates" "Found ${UPDATES[ESM]} security updates available via ESM." "Upgrade to Ubuntu Pro to apply these fixes."
        fi

        check_reboot
    else
        handle_anomalous "${UPDATES[STD]}"
    fi
}

fix_arch() {
    do_check_arch() {
        OFFICIAL_COUNT=0
        AUR_COUNT=0
        if command -v checkupdates >/dev/null 2>&1; then
            OFFICIAL_COUNT=$(checkupdates 2>/dev/null | sed '/^\s*$/d' | wc -l)
        else
            OFFICIAL_COUNT=$(pacman -Qu 2>/dev/null | sed '/^\s*$/d' | wc -l)
        fi
        if command -v yay >/dev/null 2>&1; then AUR_COUNT=$(yay -Qu 2>/dev/null | sed '/^\s*$/d' | wc -l)
        elif command -v paru >/dev/null 2>&1; then AUR_COUNT=$(paru -Qu 2>/dev/null | sed '/^\s*$/d' | wc -l)
        fi
        echo "SUCCESS|$((OFFICIAL_COUNT + AUR_COUNT))|$OFFICIAL_COUNT|$AUR_COUNT"
    }

    RAW=$(do_check_arch)
    TOTAL=$(echo "$RAW" | cut -d'|' -f2)
    OFFICIAL=$(echo "$RAW" | cut -d'|' -f3)
    AUR=$(echo "$RAW" | cut -d'|' -f4)

    if [ "$(echo "$RAW" | cut -d'|' -f1)" == "SUCCESS" ]; then
        if [ "$TOTAL" -eq 0 ]; then
            printf_success "Updates" "Arch system is fresh."
        else
            printf_warning "Updates" "Found ${TOTAL} updates (${OFFICIAL} official, ${AUR} AUR)." "Fix with ${CYAN}yay -Syu${RESET}"
            [ "$OFFICIAL" -gt 0 ] && FIX_COMMANDS+=("sudo pacman -Syu --noconfirm")
            if [ "$AUR" -gt 0 ]; then
                command -v yay >/dev/null && FIX_COMMANDS+=("yay -Syu --noconfirm") || FIX_COMMANDS+=("paru -Syu --noconfirm")
            fi
        fi
        
        check_reboot
    else
        handle_anomalous "ARCH_FAIL"
    fi
}

handle_anomalous() {
    case $1 in
        LOCKED) printf_error "Updates" "APT is currently locked." "Try again in a few minutes.";;
        TIMEOUT) printf_error "Updates" "Update check timed out." "Check your internet connection.";;
        NO_NETWORK) printf_error "Updates" "Repository sync failed." "Check your network settings.";;
        ARCH_FAIL) printf_error "Updates" "Failed to check Arch updates." "Verify pacman/yay configuration.";;
        *) printf_error "Updates" "Unknown error state ($1)." "Check module logs.";;
    esac
}

check_reboot() {
    if [ -f /var/run/reboot-required ]; then
        printf_warning "Reboot" "System requires a reboot." "Execute ${CYAN}sudo reboot${RESET} soon."
        return
    fi
    
    if [[ "${OS_INFO[ID]}" == "arch" ]]; then
        local installed_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}')
        local running_kernel=$(uname -r | cut -d'-' -f1) # Simplified comparison
        if [ ! -d "/usr/lib/modules/$(uname -r)" ]; then
             printf_warning "Reboot" "Kernel has been updated." "Running: $(uname -r), but modules missing."
        fi
    fi
}
