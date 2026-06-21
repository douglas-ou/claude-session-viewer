#!/usr/bin/env bash
set -euo pipefail

LABEL="com.claude-session-viewer"
PLIST_NAME="${LABEL}.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_SRC="$SCRIPT_DIR/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
LOG_DIR="$HOME/Library/Logs/claude-session-viewer"

get_port() {
    grep -E '^[[:space:]]*PORT[[:space:]]*=' "$SCRIPT_DIR/serve.py" | head -1 | grep -oE '[0-9]+'
}

detect_python3() {
    for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return 0
    fi
    echo "ERROR: python3 not found" >&2
    return 1
}

cmd_install() {
    if [ ! -f "$PLIST_SRC" ]; then
        echo "ERROR: Template $PLIST_SRC not found"
        exit 1
    fi
    if [ ! -f "$SCRIPT_DIR/serve.py" ]; then
        echo "ERROR: serve.py not found in $SCRIPT_DIR"
        exit 1
    fi

    if [ -f "$PLIST_DEST" ]; then
        echo "Service already installed. Reinstalling..."
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
    fi

    local py3
    py3=$(detect_python3)
    echo "Python3: $py3"

    mkdir -p "$LOG_DIR"
    mkdir -p "$HOME/Library/LaunchAgents"

    sed -e "s|__PYTHON3_PATH__|$py3|g" \
        -e "s|__PROJECT_DIR__|$SCRIPT_DIR|g" \
        -e "s|__HOME__|$HOME|g" \
        "$PLIST_SRC" > "$PLIST_DEST"

    if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
        echo "ERROR: generated plist is invalid"
        rm -f "$PLIST_DEST"
        exit 1
    fi

    launchctl load "$PLIST_DEST"

    local port
    port=$(get_port)
    echo "Installed and started."
    echo "URL: http://localhost:${port}"
    echo "Logs: $LOG_DIR/"
}

cmd_uninstall() {
    if [ ! -f "$PLIST_DEST" ]; then
        echo "Service not installed."
        exit 0
    fi
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    rm -f "$PLIST_DEST"
    echo "Service uninstalled. Logs remain in $LOG_DIR/"
}

check_loaded() {
    if ! launchctl list "$LABEL" >/dev/null 2>&1; then
        echo "Service not loaded. Run '$0 install' first."
        exit 1
    fi
}

cmd_start() {
    check_loaded
    launchctl start "$LABEL"
    echo "Started."
}

cmd_stop() {
    check_loaded
    launchctl stop "$LABEL"
    echo "Stopped."
}

cmd_restart() {
    check_loaded
    launchctl stop "$LABEL" 2>/dev/null || true
    sleep 1
    launchctl start "$LABEL"
    echo "Restarted."
}

cmd_status() {
    local port
    port=$(get_port)

    echo "Service: $LABEL"

    if launchctl list "$LABEL" >/dev/null 2>&1; then
        local info
        info=$(launchctl list "$LABEL" 2>/dev/null)
        local pid
        pid=$(echo "$info" | grep '"PID"' | grep -oE '[0-9]+')
        local exit_code
        exit_code=$(echo "$info" | grep '"LastExitStatus"' | grep -oE '[0-9]+')

        if [ -z "$pid" ]; then
            echo "State:   loaded (not running, last exit: ${exit_code:-unknown})"
        else
            echo "State:   running (PID $pid)"
        fi
    else
        echo "State:   not loaded"
    fi

    if lsof -i ":$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Port:    $port (listening)"
    else
        echo "Port:    $port (not listening)"
    fi

    echo "URL:     http://localhost:${port}"
    echo "Logs:    $LOG_DIR/"
}

cmd_logs() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_DIR/stdout.log" "$LOG_DIR/stderr.log"
    if [ "${1:-}" = "-n" ] && [ -n "${2:-}" ]; then
        tail -n "$2" "$LOG_DIR/stdout.log" "$LOG_DIR/stderr.log"
    else
        tail -f "$LOG_DIR/stdout.log" "$LOG_DIR/stderr.log"
    fi
}

case "${1:-}" in
    install)   cmd_install ;;
    uninstall) cmd_uninstall ;;
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    restart)   cmd_restart ;;
    status)    cmd_status ;;
    logs)      cmd_logs "${2:-}" "${3:-}" ;;
    *)
        echo "Usage: $0 {install|uninstall|start|stop|restart|status|logs}"
        echo ""
        echo "  install    Install and start the service (auto-start on login)"
        echo "  uninstall  Stop and remove the service"
        echo "  start      Start the service"
        echo "  stop       Stop the service"
        echo "  restart    Restart the service"
        echo "  status     Show service status"
        echo "  logs       Tail log files (use -n N for last N lines)"
        exit 1
        ;;
esac
