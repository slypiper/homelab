#!/bin/bash

fix_module() {
    local auth_keys="/home/tzappe/.ssh/authorized_keys"
    local pub_key_source="/data/ssh/homelab.pub"
    local comment="homelab2026"

    # Ensure source exists
    if [ ! -f "$pub_key_source" ]; then
        printf_error "SSH" "Source public key not found: ${pub_key_source}"
        return
    fi

    # Check for comment in authorized_keys
    if [ -f "$auth_keys" ] && grep -q "$comment" "$auth_keys"; then
        printf_success "SSH" "Authorized keys contains '${comment}'."
    else
        if [ ! -f "$auth_keys" ]; then
            printf_error "SSH" "Missing: ${auth_keys}"
            # Create dir and file with correct permissions if missing
            local ssh_dir=$(dirname "$auth_keys")
            FIX_COMMANDS+=("mkdir -p ${ssh_dir} && chmod 700 ${ssh_dir} && touch ${auth_keys} && chmod 600 ${auth_keys} && cat ${pub_key_source} >> ${auth_keys}")
        else
            printf_error "SSH" "Missing key '${comment}' in authorized_keys."
            FIX_COMMANDS+=("cat ${pub_key_source} >> ${auth_keys}")
        fi
    fi
}
