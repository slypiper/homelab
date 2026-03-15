# Log aliases

# Helpful journalctl aliases
alias  jc='journalctl'
alias jcf='journalctl -f'              # Follow new messages
alias jce='journalctl -xe'             # Check end of logs and explain errors
alias jck='journalctl -k'              # Show kernel messages (dmesg equivalent)
alias jcu='journalctl --user'          # Show logs for current user services
alias jcb='journalctl -b'              # Show logs since last boot
alias jcp='journalctl -p err..emerg'   # Show priority errors and worse
alias jct='journalctl --since "1 hour ago"' # Show recent logs

ha-logs() {
    # If not on trece, connect to it over ssh and execute the function
    if [ "$HOSTNAME" != "trece" ]; then
        if [ -n "$1" ]; then
            ssh -t trece "source /data/aliases/host-specific.sh && ha-logs '$1'"
        else
            ssh -t trece "source /data/aliases/host-specific.sh && ha-logs"
        fi
        return $?
    fi

    # Path to your Home Assistant log on the host
    local LOG_FILE="/homeassistant/home-assistant.log"
    local SEARCH_TERM="$1"

    # Check if log file exists
    if [ ! -f "$LOG_FILE" ]; then
        echo "Error: Log file not found at $LOG_FILE"
        return 1
    fi

    if [ -z "$SEARCH_TERM" ]; then
        # No argument: Show last 10 lines and tail normally
        tail -n 10 -f "$LOG_FILE"
    else
        # Argument provided: Case-insensitive search
        echo "Searching for: \"$SEARCH_TERM\""
        echo "--- Last 10 Matches ---"
        
        # Grep the file for history, limit to last 10
        grep -i "$SEARCH_TERM" "$LOG_FILE" | tail -n 10
        
        echo "--- Tailing New Matches (Ctrl+C to stop) ---"
        # Tail new lines (starting from now) and grep them
        tail -n 0 -f "$LOG_FILE" | grep --line-buffered -i "$SEARCH_TERM"
    fi
}
