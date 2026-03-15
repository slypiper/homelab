#!/bin/bash

fix_module() {
    local install_script="/data/linux/scripts.orig/cli-tools/install.sh"

    # Ensure script exists
    if [ ! -f "$install_script" ]; then
        printf_error "TOOLS" "CLI Tools install script not found: ${install_script}"
        return
    fi

    # Run dry run to see if anything needs to be installed
    local output
    output=$("$install_script" --dry_run --quiet 2>/dev/null)

    if [ -n "$output" ]; then
        # Parse output to show what's missing
        # Format: ℹ DRYRUN     Would install tool neovim
        local missing_tools
        missing_tools=$(echo "$output" | grep "Would install tool" | awk '{print $NF}' | tr '\n' ' ' | sed 's/ $//')
        
        if [ -n "$missing_tools" ]; then
            printf_warning "TOOLS" "Missing tools: ${missing_tools}"
        else
            printf_warning "TOOLS" "CLI tools need installation/updates."
        fi
        
        FIX_COMMANDS+=("${install_script} --quiet")
    else
        printf_success "TOOLS" "All CLI tools are installed."
    fi
}
