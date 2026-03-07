#!/bin/bash

# Source shflags
source /data/linux/lib/shflags/shflags

# Define Flags
DEFINE_string 'session' '' 'Name of the tmux session'  # Required
DEFINE_string 'hosts' '' 'Comma-separated list of hosts'  # Required

# Horizontal split on each host for htop
DEFINE_boolean 'htop' 'true' 'Add htop to the session'
DEFINE_string 'htop_size' '25%' 'Height percentage for the htop pane'

# One horizontal split on the first host for admin tasks
DEFINE_boolean 'admin' 'false' 'Add a full-width SSH row at the bottom for admin tasks' 'a'
DEFINE_string 'admin_size' '20%' 'Height percentage for the admin row'

# Reset and kill flags for tmux session in --session
DEFINE_boolean 'reset' 'false' 'If already open, close and recreate session' 'r'
DEFINE_boolean 'kill' 'false' 'Look for and kill any existing sessions with the same name' 'k'

# Parse command line arguments
FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

# Convert comma-separated space separated string to bash array
HOSTS=(${FLAGS_hosts//,/ })
NUM_HOSTS=${#HOSTS[@]}

# Ensure at least one host is provided
if [ "$NUM_HOSTS" -eq 0 ]; then
    echo "Error: No hosts specified."
    echo "Usage: $0 --session 'session_name' --hosts 'host1,host2,host3'"
    exit 1
fi

# Ensure a session name is provided
if [ -z "${FLAGS_session}" ]; then
    echo "Error: Session name is required."
    echo "Usage: $0 --session 'session_name' --hosts 'host1,host2,host3'"
    exit 1
fi

# Check if session exists, if it exists then attach it
if tmux has-session -t "${FLAGS_session}" 2>/dev/null; then
    if [ "${FLAGS_kill}" -eq "${FLAGS_TRUE}" ]; then
        echo "Session ${FLAGS_session} found. Killing..."
        tmux kill-session -t "${FLAGS_session}"
        exit 0
    elif [ "${FLAGS_reset}" -eq "${FLAGS_TRUE}" ]; then
        echo "Session ${FLAGS_session} already exists. Resetting..."
        tmux kill-session -t "${FLAGS_session}"
    else
        echo "Session ${FLAGS_session} already exists. Attaching..."
        tmux attach -t "${FLAGS_session}"
        exit 0
    fi
fi

# If kill flag is set and no session is found, exit
if [ "${FLAGS_kill}" -eq "${FLAGS_TRUE}" ]; then
    echo "No session found for ${FLAGS_session}."
    exit 0
fi

# Create tmux session with lazydocker on first host
tmux new-session -d -s "${FLAGS_session}" -x "$(tput cols)" -y "$(tput lines)" "ssh -t ${HOSTS[0]} lazydocker; echo 'CRASHED'; read"

# Create tmux session with lazydocker on remaining hosts
for (( i=1; i<NUM_HOSTS; i++ )); do
    tmux split-window -h -t "${FLAGS_session}" "ssh -t ${HOSTS[i]} lazydocker"
done

# Force layout to equal horizontal columns
tmux select-layout -t "${FLAGS_session}" even-horizontal

if [ "${FLAGS_htop}" -eq "${FLAGS_TRUE}" ]; then
    # Go through each column and split and add htop, then resize to $FLAGS_htop_size
    for (( i=NUM_HOSTS-1; i>=0; i-- )); do
        tmux split-window -v -t "${FLAGS_session}:0.${i}" "ssh -t ${HOSTS[i]} htop"
        tmux resize-pane -t "${FLAGS_session}" -y "${FLAGS_htop_size}"
    done
fi

if [ "${FLAGS_admin}" -eq "${FLAGS_TRUE}" ]; then
    tmux split-window -v -f -t "${FLAGS_session}" "ssh -t ${HOSTS[0]}"
    tmux resize-pane -t "${FLAGS_session}" -y "${FLAGS_admin_size}"
fi

# Enable mouse support
tmux set-option -t "${FLAGS_session}" mouse on

# Select the top-left pane
if [ "${FLAGS_admin}" -ne "${FLAGS_TRUE}" ]; then
    tmux select-pane -t "${FLAGS_session}:0.0"
else
    # Run clear in the admin pane
    tmux send-keys -t "${FLAGS_session}" "clear" C-m
fi

# Attach to the session
tmux attach -t "${FLAGS_session}"