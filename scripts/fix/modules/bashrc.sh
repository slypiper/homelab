#!/bin/bash

fix_module() {
    # Only run on Ubuntu
    if [[ "${OS_INFO[ID]}" != "ubuntu" ]]; then
        return
    fi

    local target_bashrc="${HOME}/.bashrc"
    local source_bashrc="/data/linux/config/bashrc"

    # Ensure source exists
    if [ ! -f "$source_bashrc" ]; then
        printf_error "BASHRC" "Source .bashrc not found: ${source_bashrc}"
        return
    fi

    # Check if target exists and if it differs from source
    if [ ! -f "$target_bashrc" ]; then
        printf_error "BASHRC" "Missing: ${target_bashrc}"
        FIX_COMMANDS+=("/usr/bin/cp -f ${source_bashrc} ${target_bashrc} && source ${target_bashrc} 1> /dev/null")
    elif ! diff "$target_bashrc" "$source_bashrc" >/dev/null 2>&1; then
        printf_error "BASHRC" "Local bashrc differs from source."
        FIX_COMMANDS+=("/usr/bin/cp -f ${source_bashrc} ${target_bashrc} && source ${target_bashrc} 1> /dev/null")
    else
        printf_success "BASHRC" ".bashrc is current."
    fi
}
