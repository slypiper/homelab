#!/bin/bash
source /data/linux/src/shflags/shflags
source /data/linux/lib/common.sh

DEFINE_string "host" "" "Host name of the new install."
DEFINE_string "subnet" "192.168.86" "Default IP subnet for new hosts."
DEFINE_string "ip" "" "IP of the new install. A 1-254 number will be prepended with the value of --subnet" 
DEFINE_string "group" "" "Optional Ansible group to place the host in."
DEFINE_string "config" "/data/linux/src/ansible/inventory.ini" "Ansible Inventory File."
DEFINE_boolean "dns" true "Update Pi-hole Local DNS automatically."
define_standard_flags

FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"
handle_quiet_mode

host="${FLAGS_host}"
if [ -z "$host" ]; then
    printf_prompt "INPUT" "What is the hostname?"
    read -r host
fi

if [ -z "$host" ]; then
    printf_error "ERROR" "You must specify a hostname."
    exit 1
fi

ip="${FLAGS_ip}"
if [ -z "$ip" ]; then
    printf_prompt "INPUT" "What is the IP address? (Uses ${FLAGS_subnet}.x unless specified completely)"
    read -r ip
fi

if [ -z "$ip" ]; then
    printf_error "ERROR" "You must specify an IP address."
    exit 1
fi

# Prepend subnet if IP is just the suffix (1-3 digits)
if [[ "$ip" =~ ^[0-9]{1,3}$ ]]; then
    ip="${FLAGS_subnet}.${ip}"
fi

confirm "Run installation on ${host} <=> ${ip}?"
if [ $? -ne 0 ]; then
    printf_warning "CANCEL" "Installation aborted."
    exit 0
fi

# Check and update Ansible inventory
if [ ! -f "${FLAGS_config}" ]; then
    printf_error "ERROR" "Inventory file not found: ${FLAGS_config}"
    exit 1
fi

if ! grep -q -P "^${host}\s" "${FLAGS_config}"; then
    if ! grep -q -P "=${ip}$" "${FLAGS_config}"; then
        if [ -n "${FLAGS_group}" ]; then
            group_name="${FLAGS_group}"
            printf_info "INVENTORY" "Using provided group: ${group_name}"
        else
            printf_info "INVENTORY" "Select a group for ${host}:"
            
            # Dynamically extract all regular [groups] from the INI file
            existing_groups=$(grep -oP '^\[\K[^\]]+(?=\])' "${FLAGS_config}" | grep -v ':\(children\|vars\)' | tr '\n' ' ')
            printf_info "GROUPS" "Available: ${existing_groups}"
            printf_prompt "INPUT" "Enter group name (will create if missing):"
            read -r group_name
            
            # Default to a generic group if they hit enter
            [ -z "$group_name" ] && group_name="misc"
        fi
        
        printf_info "INVENTORY" "Adding ${host} (${ip}) to [${group_name}] in ${FLAGS_config}"
        
        # Check if the group exists
        if grep -q -P "^\[${group_name}\]$" "${FLAGS_config}"; then
            # Insert the host directly below the group header
            sudo sed -i "/^\[${group_name}\]$/a ${host} ansible_host=${ip}" "${FLAGS_config}"
        else
            # Append a new group to the end of the file
            sudo sh -c "echo -e '\n[${group_name}]\n${host} ansible_host=${ip}' >> ${FLAGS_config}"
        fi
    else
        printf_warning "CONFLICT" "IP '${ip}' already exists in ${FLAGS_config}"
        confirm "Continue anyway?" || exit 0
    fi
else
    printf_warning "CONFLICT" "Host '${host}' already exists in ${FLAGS_config}"
    confirm "Continue anyway?" || exit 0
fi

# Update Pi-hole Local DNS
if [ "${FLAGS_dns}" -eq "${FLAGS_TRUE}" ]; then
    printf_info "DNS" "Configuring Pi-hole local DNS for ${host}.home..."
    /data/linux/scripts/local_dns.py --add "$ip" "${host}.home"
fi

# Run the playbook
PLAYBOOK="/data/linux/src/ansible/playbooks/new-install.yml"
if [ ! -f "$PLAYBOOK" ]; then
    printf_error "ERROR" "Playbook not found: $PLAYBOOK"
    exit 1
fi

printf_info "ANSIBLE" "Executing ansible-playbook for ${host}..."

if [ "${FLAGS_debug}" -eq "${FLAGS_TRUE}" ]; then
    ansible-playbook -vvvv -i "${FLAGS_config}" -K -l "${host}" "$PLAYBOOK"
else
    ansible-playbook -i "${FLAGS_config}" -K -l "${host}" "$PLAYBOOK"
fi

if [ $? -eq 0 ]; then
    printf_success "SUCCESS" "Installation complete for ${host}."
else
    printf_error "FAILURE" "Ansible playbook failed for ${host}."
    exit 1
fi
