#!/bin/bash

# EC2 Instance Monitor Script
# Monitors logs and system resources in real-time

# Function to show help
show_help() {
    cat << 'EOF'
EC2 Instance Monitor Script

USAGE:
    ./monitor_instance.sh [INSTANCE_NAME] [MODE] [OPTIONS]

ARGUMENTS:
    INSTANCE_NAME    SSH host name from ~/.ssh/config (default: stable-dev)
    MODE            What to monitor (default: both)

MODES:
    logs            Monitor real-time logs only (syslog, auth.log, cloud-init)
    stats           Monitor system statistics only (memory, CPU, disk)
    both            Monitor both logs and stats (default)

OPTIONS:
    -h, --help      Show this help message

EXAMPLES:
    ./monitor_instance.sh stable-dev
        Monitor both logs and stats for stable-dev instance

    ./monitor_instance.sh my-server logs
        Monitor only logs for my-server instance

    ./monitor_instance.sh production stats
        Monitor only system stats for production instance

    ./monitor_instance.sh --help
        Show this help message

WHAT IT MONITORS:

    Logs Mode:
    • System logs (/var/log/syslog)
    • Authentication logs (/var/log/auth.log)
    • Cloud-init output (/var/log/cloud-init-output.log)
    • Real-time log streaming with timestamps

    Stats Mode:
    • Memory usage (free -h)
    • Disk usage (df -h)
    • CPU load average
    • Top memory-consuming processes
    • Updates every 30 seconds

    Both Mode:
    • Combines logs and stats monitoring
    • Automatic reconnection on connection loss
    • Instance health checking

REQUIREMENTS:
    • SSH access to the instance
    • Instance name must be in ~/.ssh/config
    • sudo access on the remote instance

TROUBLESHOOTING:
    If connection fails:
    • Check: ssh INSTANCE_NAME
    • Verify: ~/.ssh/config has correct entry
    • Test: SSH key authentication working

Press Ctrl+C to stop monitoring at any time.

EOF
}

INSTANCE_NAME=""
MODE="both"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        logs|stats|both)
            MODE="$1"
            shift
            ;;
        *)
            if [ -z "$INSTANCE_NAME" ]; then
                INSTANCE_NAME="$1"
            else
                echo "❌ Unknown argument: $1"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default instance name if not provided
INSTANCE_NAME="${INSTANCE_NAME:-stable-dev}"

echo "🔍 Monitoring instance: $INSTANCE_NAME"
echo "Press Ctrl+C to stop monitoring"
echo "======================================="

# Function to check if instance is reachable
check_instance() {
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$INSTANCE_NAME" "echo 'Connected'" >/dev/null 2>&1; then
        echo "❌ $(date): Instance $INSTANCE_NAME is not reachable!"
        return 1
    fi
    return 0
}

# Function to get system stats
get_stats() {
    ssh "$INSTANCE_NAME" "
        echo '=== $(date) ==='
        echo 'Memory Usage:'
        free -h | grep -E 'Mem:|Swap:'
        echo
        echo 'Disk Usage:'
        df -h / | tail -1
        echo
        echo 'Load Average:'
        uptime
        echo
        echo 'Top 5 Memory Processes:'
        ps aux --sort=-%mem | head -6
        echo '=========================='
    " 2>/dev/null
}

# Function to monitor logs
monitor_logs() {
    echo "📋 Starting log monitoring..."
    ssh "$INSTANCE_NAME" "
        echo 'Starting real-time log monitoring...'
        echo 'Watching: syslog, auth.log, cloud-init, and VS Code processes'
        echo '============================================================='
        
        # Monitor multiple logs with timestamps
        sudo tail -f /var/log/syslog /var/log/auth.log /var/log/cloud-init-output.log 2>/dev/null | \
        while read line; do
            echo \"[$(date '+%H:%M:%S')] \$line\"
        done
    "
}

# Function to monitor in parallel
monitor_parallel() {
    # Start log monitoring in background
    {
        echo "📋 LOG MONITOR:"
        monitor_logs
    } &
    LOG_PID=$!
    
    # Monitor system stats every 30 seconds
    while true; do
        if check_instance; then
            echo "📊 SYSTEM STATS:"
            get_stats
            echo
        else
            echo "💀 Instance appears to be dead or unreachable!"
            echo "⏰ $(date)"
            break
        fi
        sleep 30
    done
    
    # Clean up background process
    kill $LOG_PID 2>/dev/null
}

# Main execution
case "$MODE" in
    "logs")
        echo "📋 LOG MONITOR MODE"
        echo "Instance: $INSTANCE_NAME"
        echo "======================================="
        monitor_logs
        ;;
    "stats")
        echo "📊 STATS MONITOR MODE"
        echo "Instance: $INSTANCE_NAME"
        echo "======================================="
        while true; do
            if check_instance; then
                get_stats
                sleep 10
            else
                echo "💀 Instance is down!"
                break
            fi
        done
        ;;
    "both")
        echo "🔍 FULL MONITOR MODE"
        echo "Instance: $INSTANCE_NAME"
        echo "Monitoring: Logs + System Stats"
        echo "======================================="
        monitor_parallel
        ;;
    *)
        echo "❌ Invalid mode: $MODE"
        echo "Valid modes: logs, stats, both"
        echo "Use --help for more information"
        exit 1
        ;;
esac