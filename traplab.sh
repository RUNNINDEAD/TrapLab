#!/bin/bash

RUN_TS=$(date '+%Y%m%d_%H%M%S')
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

SSH_LOG="$LOG_DIR/ssh_monitor_${RUN_TS}.log"
PING_LOG="$LOG_DIR/ping_monitor_${RUN_TS}.log"
HTTP_LOG="$LOG_DIR/http_monitor_${RUN_TS}.log"

VERBOSE=false
DO_SSH=false
DO_PING=false
DO_HTTP=false
DO_ALL=false
INTERFACE="eth0"  # Default

trap 'cleanup_and_exit' SIGINT

cleanup_and_exit() {
    echo -e "\n[EXIT] TrapLab stopped. Goodbye!"
    kill 0
    exit 0
}

print_banner() {
echo "  _____                _          _     "
echo " |_   _| __ __ _ _ __ | |    __ _| |__  "
echo "   | || '__/ _\` | '_ \| |   / _\` | '_ \ "
echo "   | || | | (_| | |_) | |__| (_| | |_) |"
echo "   |_||_|  \__,_| .__/|_____\__,_|_.__/ "
echo "                |_|                     "
echo ""
echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')"
echo "Monitoring interface: $INTERFACE"
echo "Press [q] to quit anytime."
echo ""
}

output() {
    local text="$1"
    if $VERBOSE; then
        echo "$text"
    fi
}

monitor_ssh() {
    output "[TrapLab] Monitoring SSH logins... log: $SSH_LOG"
    echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$SSH_LOG"
    tail -Fn0 /var/log/auth.log | \
    while read line ; do
        echo "$line" | grep "Accepted password\|Accepted publickey" | grep "ssh"
        if [ $? = 0 ]; then
            TIMESTAMP=$(echo "$line" | awk '{print $1, $2, $3}')
            USER=$(echo "$line" | sed -n 's/.*Accepted.*for \(.*\) from.*/\1/p')
            IP=$(echo "$line" | sed -n 's/.*from \(.*\) port.*/\1/p')

            ALERT="[LOGIN] $TIMESTAMP - User: $USER - IP: $IP"
            output "$ALERT"
            echo "$ALERT" >> "$SSH_LOG"
        fi
    done
}

monitor_ping() {
    output "[TrapLab] Monitoring ICMP (ping)... log: $PING_LOG"
    echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$PING_LOG"
    sudo tcpdump -i $INTERFACE -l -nn icmp | \
    while read line ; do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        ALERT="[PING] $TIMESTAMP - $line"
        output "$ALERT"
        echo "$ALERT" >> "$PING_LOG"
    done
}

monitor_http() {
    output "[TrapLab] Monitoring HTTP requests... log: $HTTP_LOG"
    echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$HTTP_LOG"
    sudo tcpdump -i $INTERFACE -l -nn port 80 or port 443 | \
    while read line ; do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        ALERT="[HTTP] $TIMESTAMP - $line"
        output "$ALERT"
        echo "$ALERT" >> "$HTTP_LOG"
    done
}

watch_quit() {
    while true; do
        read -n1 -s key
        if [[ $key = "q" ]]; then
            echo -e "\n[EXIT] TrapLab stopped by user (q). Goodbye!"
            kill 0
            exit 0
        fi
    done
}

# --- MAIN ---

watch_quit &

print_banner

# Parse args
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -s) DO_SSH=true; shift ;;
        -p) DO_PING=true; shift ;;
        -h) DO_HTTP=true; shift ;;
        -a) DO_ALL=true; shift ;;
        -v) VERBOSE=true; shift ;;
        -i) INTERFACE="$2"; shift 2 ;;
        --help|-help) 
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -s        Monitor SSH logins"
            echo "  -p        Monitor ICMP (ping)"
            echo "  -h        Monitor HTTP traffic (port 80/443)"
            echo "  -a        Monitor ALL protocols"
            echo "  -v        Verbose mode (show output to screen)"
            echo "  -i iface  Select network interface (default: eth0)"
            echo "  --help    Show this help message"
            echo ""
            echo "Press [q] at any time to quit."
            exit 0
            ;;
        *) 
            echo "Unknown option: $1"
            echo "Try: $0 --help"
            exit 1
            ;;
    esac
done

# If no args, show usage
if ! $DO_SSH && ! $DO_PING && ! $DO_HTTP && ! $DO_ALL; then
    echo "Usage: $0 --help for usage"
    exit 1
fi

# Start monitors
if $DO_ALL; then
    monitor_ssh &  
    monitor_ping & 
    monitor_http & 
else
    if $DO_SSH; then monitor_ssh & fi
    if $DO_PING; then monitor_ping & fi
    if $DO_HTTP; then monitor_http & fi
fi

wait
