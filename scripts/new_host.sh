#!/bin/bash
source /data/linux/src/shflags/shflags
source /data/linux/lib/common.sh

DEFINE_string "host" "" "Host name of the new install."
DEFINE_string "subnet" "192.168.86" "Default IP subnet for new hosts."
DEFINE_string "ip" "" "IP of the new install. A 1-254 number will be prepended with the value of --subnet" 
DEFINE_string "group" "" "Optional Ansible group to place the host in."
DEFINE_string "config" "/data/linux/src/ansible/inventory.ini" "Ansible Inventory File."
DEFINE_boolean "dns" true "Update Pi-hole Local DNS automatically."
DEFINE_boolean "ansible_debug" false "Show verbose ansible-playbook output (-vvvv)"
define_standard_flags

FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"
handle_quiet_mode

LOG_DIR="/data/ansible/logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP=$(date +%Y%m%d.%H%M)

# Internal helper to run a command with logging and optional real-time debug streaming
run_logged() {
    local label=$1
    local log_file=$2
    shift 2 # The rest is the command
    
    local res=0
    if [ "${FLAGS_debug}" -eq "${FLAGS_TRUE}" ]; then
        # Stream live to terminal + log
        # Force color for ansible if found in command
        export PYTHONUNBUFFERED=1
        if [[ "$*" == *"ansible-playbook"* ]]; then
            export ANSIBLE_FORCE_COLOR=true
        fi

        # We use a subshell to capture the output while keeping the exit code of the command
        stdbuf -oL -eL "$@" 2>&1 | sed -u 's/\r//g' | stdbuf -oL tee "${log_file}" | while IFS= read -r line; do
            [[ "$line" =~ [^[:space:]] ]] && printf_debug "${label}" "$line"
        done
        res=${PIPESTATUS[0]}
    else
        # Run silent to log
        "$@" 2>&1 | sed -u 's/\r//g' > "${log_file}"
        res=${PIPESTATUS[0]}
    fi
    return $res
}

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
    DNS_LOG="${LOG_DIR}/${TIMESTAMP}.${host}.dns"
    printf_info "DNS" "Configuring Pi-hole local DNS for ${host}.home..."
    
    if run_logged "DNS" "${DNS_LOG}" /data/linux/scripts/local_dns.py --add "$ip" "${host}.home"; then
        printf_success "SUCCESS" "Local DNS good for ${host}.home (Logged to ${DNS_LOG})"
    else
        [ "${FLAGS_debug}" -eq "${FLAGS_FALSE}" ] && [ -f "${DNS_LOG}" ] && cat "${DNS_LOG}"
        printf_error "FAILURE" "Local DNS configuration failed (Logged to ${DNS_LOG})"
        exit 1
    fi
fi

# Run the playbook
PLAYBOOK="/data/linux/src/ansible/playbooks/new-install.yml"
if [ ! -f "$PLAYBOOK" ]; then
    printf_error "ERROR" "Playbook not found: $PLAYBOOK"
    exit 1
fi

ANSIBLE_LOG="${LOG_DIR}/${TIMESTAMP}.${host}.ansible"
ANSIBLE_OPTS=()
[ "${FLAGS_ansible_debug}" -eq "${FLAGS_TRUE}" ] && ANSIBLE_OPTS+=("-vvvv")

printf_info "ANSIBLE" "Executing ansible-playbook for ${host}. (Logged to ${ANSIBLE_LOG})"

if run_logged "ANSIBLE" "${ANSIBLE_LOG}" ansible-playbook "${ANSIBLE_OPTS[@]}" -i "${FLAGS_config}" -l "${host}" "$PLAYBOOK"; then
    printf_success "SUCCESS" "Installation complete for ${host}."
else
    [ "${FLAGS_debug}" -eq "${FLAGS_FALSE}" ] && [ -f "${ANSIBLE_LOG}" ] && cat "${ANSIBLE_LOG}"
    printf_error "FAILURE" "Ansible playbook failed for ${host}."
    exit 1
fi
