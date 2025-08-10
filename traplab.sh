#!/bin/bash

# TrapLab — network activity monitor
# - Folders: logs/ssh, logs/ping, logs/http/{80,443}
# - HTTP split by port (80/443) + combined http log
# - Safe cleanup (no kill 0)

RUN_TS=$(date '+%Y%m%d_%H%M%S')

# === LOG LAYOUT ===
LOG_DIR="./logs"
SSH_DIR="$LOG_DIR/ssh"
PING_DIR="$LOG_DIR/ping"
HTTP_DIR="$LOG_DIR/http"
HTTP_80_DIR="$HTTP_DIR/80"
HTTP_443_DIR="$HTTP_DIR/443"

mkdir -p "$SSH_DIR" "$PING_DIR" "$HTTP_DIR" "$HTTP_80_DIR" "$HTTP_443_DIR"

SSH_LOG="$SSH_DIR/ssh_monitor_${RUN_TS}.log"
PING_LOG="$PING_DIR/ping_monitor_${RUN_TS}.log"
HTTP_COMBINED_LOG="$HTTP_DIR/http_monitor_${RUN_TS}.log"
HTTP80_LOG="$HTTP_80_DIR/http_80_${RUN_TS}.log"
HTTP443_LOG="$HTTP_443_DIR/http_443_${RUN_TS}.log"

VERBOSE=false
DO_SSH=false
DO_PING=false
DO_HTTP=false
DO_ALL=false
INTERFACE="eth0"  # Default

trap 'cleanup_and_exit' SIGINT SIGTERM

cleanup_and_exit() {
    echo -e "\n[EXIT] TrapLab stopped. Goodbye!"
    # Kill ONLY background jobs started by this script
    jobs -p | xargs -r kill 2>/dev/null
    wait 2>/dev/null
    exit 0
}

print_banner() {
echo "  _____                _          _     "
echo " |_   _| __ __ _ _ __ | |    __ _| |__  "
echo "   | || '__/ _\` | '_ \\| |   / _\` | '_ \\ "
echo "   | || | | (_| | |_) | |__| (_| | |_) |"
echo "   |_||_|  \\__,_| .__/|_____\\__,_|_.__/ "
echo "                |_|                     "
echo ""
echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')"
echo "Monitoring interface: $INTERFACE"
echo "Logs:"
echo "  SSH : $SSH_DIR"
echo "  PING: $PING_DIR"
echo "  HTTP: $HTTP_DIR (80 -> $HTTP_80_DIR , 443 -> $HTTP_443_DIR)"
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
    # Pick auth file (Debian/Kali: auth.log, RHEL/CentOS: secure)
    local AUTH_FILE="/var/log/auth.log"
    [[ -f /var/log/secure ]] && AUTH_FILE="/var/log/secure"

    if [[ ! -f "$AUTH_FILE" ]]; then
        echo "[SSH] Could not find auth log file (looked for /var/log/auth.log and /var/log/secure)" | tee -a "$SSH_LOG"
        return
    fi

    output "[TrapLab] Monitoring SSH logins... log: $SSH_LOG"
    echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$SSH_LOG"

    tail -Fn0 "$AUTH_FILE" | \
    while read -r line ; do
        echo "$line" | grep -E "Accepted (password|publickey).*sshd" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            TIMESTAMP=$(echo "$line" | awk '{print $1, $2, $3}')
            USER=$(echo "$line" | sed -n 's/.*Accepted .* for \([^ ]*\) from.*/\1/p')
            IP=$(echo "$line" | sed -n 's/.* from \([^ ]*\) port .*/\1/p')
            ALERT="[LOGIN] $TIMESTAMP - User: ${USER:-unknown} - IP: ${IP:-unknown}"
            output "$ALERT"
            echo "$ALERT" >> "$SSH_LOG"
        fi
    done
}

monitor_ping() {
    output "[TrapLab] Monitoring ICMP (ping)... log: $PING_LOG"
    echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$PING_LOG"
    sudo tcpdump -i "$INTERFACE" -l -nn icmp | \
    while read -r line ; do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        ALERT="[PING] $TIMESTAMP - $line"
        output "$ALERT"
        echo "$ALERT" >> "$PING_LOG"
    done
}

monitor_http_port() {
    local PORT="$1"
    local PORT_LOG="$2"

    output "[TrapLab] Monitoring HTTP port $PORT ... log: $PORT_LOG"
    echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$PORT_LOG"

    sudo tcpdump -i "$INTERFACE" -l -nn "tcp port $PORT" | \
    while read -r line ; do
        local TIMESTAMP
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        local ALERT="[HTTP:$PORT] $TIMESTAMP - $line"
        output "$ALERT"
        echo "$ALERT" >> "$PORT_LOG"
        echo "$ALERT" >> "$HTTP_COMBINED_LOG"
    done
}

monitor_http() {
    # Touch combined header once
    echo "[TrapLab] Started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$HTTP_COMBINED_LOG"
    monitor_http_port 80  "$HTTP80_LOG"  &
    monitor_http_port 443 "$HTTP443_LOG" &
    wait
}

watch_quit() {
    while true; do
        read -n1 -s key
        if [[ $key = "q" ]]; then
            echo -e "\n[EXIT] TrapLab stopped by user (q). Goodbye!"
            cleanup_and_exit
        fi
    done
}

# --- MAIN ---

# Parse args first (so banner shows chosen iface/verbosity)
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
            echo "  -h        Monitor HTTP traffic (80/443; split into folders)"
            echo "  -a        Monitor ALL"
            echo "  -v        Verbose output"
            echo "  -i iface  Select network interface (default: eth0)"
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

print_banner

# If no args, show usage
if ! $DO_SSH && ! $DO_PING && ! $DO_HTTP && ! $DO_ALL; then
    echo "Usage: $0 --help for usage"
    exit 1
fi

watch_quit &

# Start monitors
if $DO_ALL; then
    monitor_ssh &
    monitor_ping &
    monitor_http &
else
    $DO_SSH  && monitor_ssh  &
    $DO_PING && monitor_ping &
    $DO_HTTP && monitor_http &
fi

wait

