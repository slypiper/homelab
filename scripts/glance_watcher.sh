#!/bin/bash

source /data/linux/src/shflags/shflags
source /data/linux/lib/common.sh

DEFINE_string "directory" "/data/docker/glance/config" "Directory to watch for modifications."
DEFINE_string "service_name" "dash_glance" "Name of the swarm service to force update."
DEFINE_string "host" "once" "Host to execute the watcher on."
DEFINE_integer "sleep_secs" "2" "Seconds to sleep between loop iterations."
define_standard_flags

ORIGINAL_ARGS=("$@")
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"
handle_quiet_mode

if [ "$HOSTNAME" != "${FLAGS_host}" ]; then
    printf_info "WATCHER" "Redirecting execution to host '${FLAGS_host}' via tmux..."
    ssh -t "${FLAGS_host}" "
        if ! tmux has-session -t glance_watcher 2>/dev/null; then
            echo -e \"\e[97m\e[1mℹ WATCHER   \e[0m Creating new tmux session: \e[36mglance_watcher\e[0m\"
            tmux new-session -d -s glance_watcher '$(realpath "$0") ${ORIGINAL_ARGS[*]}'
        else
            echo -e \"\e[97m\e[1mℹ WATCHER   \e[0m Attaching to existing tmux session: \e[36mglance_watcher\e[0m\"
        fi
        tmux attach-session -t glance_watcher
    "
    exit 0
fi

WATCH_DIR=${FLAGS_directory}
RESTART_COMMAND="docker service update --force --quiet ${FLAGS_service_name}"
SLEEP_INTERVAL=${FLAGS_sleep_secs}

if [ ! -d "$WATCH_DIR" ]; then
    printf_error "WATCHER" "The directory '${WATCH_DIR}' does not exist."
    exit 1
fi

printf_info "WATCHER" "Watching directory: ${WATCH_DIR} for changes to *.yml files..."

# Capture Baseline State (looking for both .yml and .yaml recursively)
LAST_MODIFIED_TIME=$(fdfind -e yml -e yaml . "$WATCH_DIR" -X stat -c %Y 2>/dev/null | sort -nr | head -n 1)
[ -z "$LAST_MODIFIED_TIME" ] && LAST_MODIFIED_TIME=0

printf_info "WATCHER" "Polling directory every ${SLEEP_INTERVAL}s."
while true; do
    sleep "$SLEEP_INTERVAL"

    # Find the most recent modification time recursively for both .yml and .yaml
    LATEST_MODIFIED_TIME=$(fdfind -e yml -e yaml . "$WATCH_DIR" -X stat -c %Y 2>/dev/null | sort -nr | head -n 1)
    
    # Handle empty directory gracefully
    [ -z "$LATEST_MODIFIED_TIME" ] && LATEST_MODIFIED_TIME=0

    # Float comparison safely
    IS_NEWER=$(awk -v current="$LATEST_MODIFIED_TIME" -v last="$LAST_MODIFIED_TIME" 'BEGIN { print (current > last) }')

    if [ "$IS_NEWER" -eq 1 ]; then
        # Strip trailing decimals for standard date compatibility 
        clean_time="${LATEST_MODIFIED_TIME%.*}"
        printf_info "DETECTED" "Modification detected at: $(date -d @"$clean_time")"
        
        # Restart
        printf_info "RESTART"  "Restarting ${FLAGS_service_name}..."
        eval "$RESTART_COMMAND" > /dev/null
        
        if [ $? -eq 0 ]; then
            printf_success "SUCCESS" "Service restarted successfully at $(date '+%Y-%m-%d %H:%M:%S')."
        else
            printf_error "ERROR" "Failed to restart the service."
        fi
        
        LAST_MODIFIED_TIME=$LATEST_MODIFIED_TIME
    fi
done
