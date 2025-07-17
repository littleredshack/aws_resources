#!/bin/bash

# VS Code Tunnel Service Setup Script
# Sets up VS Code tunnel as a systemd service on remote instance

set -e

INSTANCE_NAME="${1:-stable-dev}"

# Function to show help
show_help() {
    cat << 'EOF'
VS Code Tunnel Service Setup Script

USAGE:
    ./setup_tunnel_service.sh [INSTANCE_NAME] [OPTIONS]

ARGUMENTS:
    INSTANCE_NAME    SSH host name from ~/.ssh/config (default: stable-dev)

OPTIONS:
    -h, --help      Show this help message
    -s, --status    Check tunnel service status only
    -r, --restart   Restart existing tunnel service
    -u, --url       Get tunnel URL from service logs

EXAMPLES:
    ./setup_tunnel_service.sh stable-dev
        Set up tunnel service on stable-dev instance

    ./setup_tunnel_service.sh my-server
        Set up tunnel service on my-server instance

    ./setup_tunnel_service.sh stable-dev --status
        Check if tunnel service is running

    ./setup_tunnel_service.sh stable-dev --url
        Get the tunnel URL

WHAT IT DOES:
    • Creates systemd service file for VS Code tunnel
    • Enables auto-start on boot
    • Starts the tunnel service
    • Shows tunnel URL and management commands

REQUIREMENTS:
    • SSH access to the instance
    • sudo access on remote instance
    • VS Code already installed on instance

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--status)
            ACTION="status"
            shift
            ;;
        -r|--restart)
            ACTION="restart"
            shift
            ;;
        -u|--url)
            ACTION="url"
            shift
            ;;
        *)
            if [[ "$1" =~ ^- ]]; then
                echo "❌ Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
            else
                INSTANCE_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Function to check SSH connectivity
check_ssh() {
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$INSTANCE_NAME" "echo 'SSH OK'" >/dev/null 2>&1; then
        echo "❌ Cannot connect to instance: $INSTANCE_NAME"
        echo "Check your SSH config and instance status"
        exit 1
    fi
}

# Function to check service status
check_status() {
    echo "🔍 Checking VS Code tunnel service status on $INSTANCE_NAME..."
    ssh "$INSTANCE_NAME" "
        if systemctl is-active --quiet vscode-tunnel.service; then
            echo '✅ VS Code tunnel service is running'
            systemctl status vscode-tunnel.service --no-pager -l
        else
            echo '❌ VS Code tunnel service is not running'
            echo 'Status:'
            systemctl status vscode-tunnel.service --no-pager -l || true
        fi
    "
}

# Function to restart service
restart_service() {
    echo "🔄 Restarting VS Code tunnel service on $INSTANCE_NAME..."
    ssh "$INSTANCE_NAME" "
        sudo systemctl restart vscode-tunnel.service
        echo '✅ Service restarted'
        sleep 3
        systemctl status vscode-tunnel.service --no-pager -l
    "
}

# Function to get tunnel URL
get_url() {
    echo "🔗 Getting tunnel URL from $INSTANCE_NAME..."
    ssh "$INSTANCE_NAME" "
        echo 'Checking service logs for tunnel URL...'
        sudo journalctl -u vscode-tunnel.service --no-pager | grep -i 'open this link' | tail -1 || echo 'No tunnel URL found in logs yet'
        echo
        echo 'Recent service status:'
        systemctl status vscode-tunnel.service --no-pager -l
    "
}

# Function to setup tunnel service
setup_service() {
    echo "🚀 Setting up VS Code tunnel service on $INSTANCE_NAME..."
    
    # Check if VS Code is installed
    echo "   Checking if VS Code is installed..."
    ssh "$INSTANCE_NAME" "
        if ! command -v code >/dev/null 2>&1; then
            echo '❌ VS Code is not installed. Installing via snap...'
            sudo snap install code --classic
        else
            echo '✅ VS Code is already installed'
        fi
    "
    
    # Create and install systemd service
    echo "   Creating systemd service..."
    ssh "$INSTANCE_NAME" "
        echo 'Creating vscode-tunnel.service...'
        sudo tee /etc/systemd/system/vscode-tunnel.service > /dev/null << 'EOF'
[Unit]
Description=VS Code Tunnel
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/snap/bin/code tunnel --accept-server-license-terms
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        echo '✅ Service file created'
    "
    
    # Enable and start service
    echo "   Enabling and starting service..."
    ssh "$INSTANCE_NAME" "
        sudo systemctl daemon-reload
        sudo systemctl enable vscode-tunnel.service
        sudo systemctl start vscode-tunnel.service
        echo '✅ Service enabled and started'
    "
    
    # Wait a moment and check status
    echo "   Checking service status..."
    sleep 5
    ssh "$INSTANCE_NAME" "
        if systemctl is-active --quiet vscode-tunnel.service; then
            echo '✅ VS Code tunnel service is running successfully!'
            echo
            echo 'Service status:'
            systemctl status vscode-tunnel.service --no-pager -l
        else
            echo '❌ Service failed to start'
            echo 'Error details:'
            sudo journalctl -u vscode-tunnel.service --no-pager -l
            exit 1
        fi
    "
    
    # Show management commands
    echo ""
    echo "🎉 VS Code tunnel service setup complete!"
    echo ""
    echo "📋 Management Commands:"
    echo "  Check status: ./setup_tunnel_service.sh $INSTANCE_NAME --status"
    echo "  Get URL:      ./setup_tunnel_service.sh $INSTANCE_NAME --url"
    echo "  Restart:      ./setup_tunnel_service.sh $INSTANCE_NAME --restart"
    echo ""
    echo "🔧 Direct SSH Commands:"
    echo "  Status:       ssh $INSTANCE_NAME 'sudo systemctl status vscode-tunnel.service'"
    echo "  Logs:         ssh $INSTANCE_NAME 'sudo journalctl -u vscode-tunnel.service -f'"
    echo "  Restart:      ssh $INSTANCE_NAME 'sudo systemctl restart vscode-tunnel.service'"
    echo ""
    echo "⏰ Getting tunnel URL (may take 30-60 seconds)..."
    sleep 10
    get_url
}

# Main execution
echo "🔧 VS Code Tunnel Service Manager"
echo "Instance: $INSTANCE_NAME"
echo "======================================="

# Check SSH connectivity first
check_ssh

# Execute based on action
case "${ACTION:-setup}" in
    status)
        check_status
        ;;
    restart)
        restart_service
        ;;
    url)
        get_url
        ;;
    setup)
        setup_service
        ;;
    *)
        echo "❌ Unknown action: $ACTION"
        exit 1
        ;;
esac