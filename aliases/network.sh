# Network Aliases and Functions

alias whereami="wget -qO - http://ipinfo.io"
alias whatismyip="whatsmyip"
function whatsmyip() {
  if command -v ip &>/dev/null; then
    echo -n "Internal IP: "
    ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
  else
    echo -n "Internal IP: "
    ifconfig wlan0 | grep "inet " | awk '{print $2}'
  fi

  echo -n "External IP: "
  curl -s ifconfig.me
}
