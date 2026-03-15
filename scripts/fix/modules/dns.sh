#!/bin/bash

fix_module() {

    local target_dns="192.168.86.2"
    
    check_dns_config() {
        local dns_servers=""
        command -v resolvectl >/dev/null 2>&1 && dns_servers=$(resolvectl dns 2>/dev/null)
        [ -f /etc/resolv.conf ] && dns_servers="${dns_servers} $(grep "nameserver" /etc/resolv.conf)"

        if [[ "$dns_servers" == *"$target_dns"* ]]; then
            echo "SUCCESS"
        else
            echo "FAILURE|$(ip route | grep '^default' | awk '{print $5}' | head -n1)"
        fi
    }

    local raw=$(check_dns_config)

    if [ "$(echo "$raw" | cut -d'|' -f1)" == "SUCCESS" ]; then
        printf_success "DNS" "Correctly pointed to ${target_dns}."
    else
        local iface=$(echo "$raw" | cut -d'|' -f2)
        printf_error "DNS" "Not pointed to ${target_dns}."
        if [ -n "$iface" ]; then
            printf_debug "DNS" "Detected ${iface} as gateway interface."
            if command -v resolvectl >/dev/null 2>&1; then
                 FIX_COMMANDS+=("sudo resolvectl dns ${iface} ${target_dns} && sudo resolvectl flush-caches")
            fi
        fi
    fi
}
