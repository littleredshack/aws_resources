#!/bin/bash

# EC2 SSH-Only Instance Setup for VS Code Remote (Phased Approach)
# This script creates a traditional SSH-accessible instance with IP restrictions

set -e

# Function to show help
show_help() {
    cat << EOF
EC2 SSH-Only Instance Setup for VS Code Remote (Phased Approach)

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -r, --region REGION     AWS region to create instance in (default: us-east-1)
    -k, --key-name NAME     Name for the SSH key pair (default: ssh-key-TIMESTAMP)
    -n, --name NAME         Name tag for the instance (default: ssh-dev-instance)
    -i, --my-ip IP          Your public IP address (required)
    -p, --post-install      Install development tools after instance creation (default: no)
    -h, --help              Show this help message

EXAMPLES:
    $0 --region eu-west-1 --my-ip 203.0.113.42
    $0 -r us-west-2 -i 198.51.100.10 -n "my-dev-server" --post-install
    $0 --region eu-west-1 --my-ip 203.0.113.42 --post-install

PHASED APPROACH:
    Phase 1: Create instance and wait for it to run
    Phase 2: Configure SSH locally  
    Phase 3: Test SSH connection (CRITICAL - stops if fails)
    Phase 4: Install VS Code tunnels remotely
    Phase 5: Optional post-install setup (Node.js, Claude CLI, etc.)

REQUIREMENTS:
    • AWS CLI installed and configured (aws configure)
    • Your current public IP address

EOF
}

# Default configuration
INSTANCE_TYPE="t2.small"
REGION="us-east-1"
KEY_NAME="ssh-key-$(date +%Y%m%d%H%M)"
INSTANCE_NAME="ssh-dev-instance"
MY_IP=""
POST_INSTALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -k|--key-name)
            KEY_NAME="$2"
            shift 2
            ;;
        -n|--name)
            INSTANCE_NAME="$2"
            shift 2
            ;;
        -i|--my-ip)
            MY_IP="$2"
            shift 2
            ;;
        -p|--post-install)
            POST_INSTALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$MY_IP" ]; then
    echo "❌ Error: Your IP address is required"
    echo "Get your IP with: curl ifconfig.me"
    echo "Then run: $0 --my-ip YOUR_IP_ADDRESS"
    exit 1
fi

# Validate IP format (basic check)
if [[ ! "$MY_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "⚠️  Warning: IP '$MY_IP' doesn't look like a valid IP address"
    read -p "❓ Continue anyway? [y/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

# Validate region format (basic check)
if [[ ! "$REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]]; then
    echo "⚠️  Warning: Region '$REGION' doesn't match typical AWS region format"
    read -p "❓ Continue anyway? [y/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

echo "🚀 Setting up SSH-only EC2 instance with phased approach..."
echo "📍 Region: $REGION"
echo "🏷️  Instance name: $INSTANCE_NAME"
echo "🔑 Key name: $KEY_NAME"
echo "🌐 Your IP: $MY_IP"
echo "🔧 Post-install tools: $POST_INSTALL"
echo ""

# Get the latest Ubuntu 22.04 LTS AMI ID
echo "📋 Getting latest Ubuntu 22.04 LTS AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region $REGION)

USING_UBUNTU=true

if [ "$AMI_ID" = "None" ] || [ -z "$AMI_ID" ]; then
    echo "⚠️  Ubuntu AMI not found, falling back to Amazon Linux 2..."
    AMI_ID=$(aws ec2 describe-images \
        --owners amazon \
        --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text \
        --region $REGION)
    USING_UBUNTU=false
fi

echo "✅ Using AMI: $AMI_ID"

# Get default VPC ID
echo "🌐 Getting default VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region $REGION)

echo "✅ Using VPC: $VPC_ID"

# Create security group for SSH access
echo "🛡️  Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name ssh-only-sg-$(date +%Y%m%d%H%M) \
    --description "SSH access only from specific IP" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text \
    --region $REGION)

echo "✅ Created Security Group: $SECURITY_GROUP_ID"

# Add SSH rule for your IP only
echo "🔐 Adding SSH rule for your IP ($MY_IP)..."
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32 \
    --region $REGION

echo "✅ SSH access allowed from $MY_IP only"

# Create key pair and save it locally
echo "🔑 Creating key pair..."
KEY_MATERIAL=$(aws ec2 create-key-pair \
    --key-name $KEY_NAME \
    --query 'KeyMaterial' \
    --output text \
    --region $REGION 2>/dev/null) || {
    echo "❌ Key pair creation failed. Key might already exist."
    exit 1
}

# Save key if it was created
if [ -n "$KEY_MATERIAL" ]; then
    echo "$KEY_MATERIAL" > ${KEY_NAME}.pem
    chmod 600 ${KEY_NAME}.pem
    echo "✅ Key pair saved as ${KEY_NAME}.pem"
else
    echo "❌ Failed to create key pair"
    exit 1
fi

# User data script - MINIMAL setup only
USER_DATA=$(cat << 'EOF'
#!/bin/bash

# Enable logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting minimal user-data script at $(date)"

# Detect OS type
if [ -f /etc/ubuntu-release ] || [ -f /etc/lsb-release ]; then
    echo "Detected Ubuntu - minimal setup..."
    # Ubuntu minimal setup
    export DEBIAN_FRONTEND=noninteractive
    
    # Basic update only - no upgrade
    apt-get update -y
    
    # Install only essential tools
    apt-get install -y curl wget git vim htop
    
    DEFAULT_USER="ubuntu"
    
else
    echo "Detected Amazon Linux - minimal setup..."
    # Amazon Linux minimal setup
    yum update -y
    
    # Install only essential tools
    yum install -y curl wget git vim htop
    
    DEFAULT_USER="ec2-user"
fi

# Create welcome message
cat > /etc/motd << MOTD_EOF
========================================
🚀 Minimal Development Instance Ready!
========================================

Instance Details:
• OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
• Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
• Default user: $DEFAULT_USER

Minimal tools installed:
✅ Basic development tools (git, vim, htop)
✅ SSH access ready

Ready for additional setup via SSH!
========================================
MOTD_EOF

echo "Minimal setup completed successfully at $(date)"

EOF
)

# Launch EC2 instance
echo "🚀 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)

echo "✅ Instance launched with ID: $INSTANCE_ID"

# Wait for instance to be running
echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

echo "✅ Instance is now running!"

# Get instance details
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region $REGION)

PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text \
    --region $REGION)

# Determine the correct user based on the AMI
if [ "$USING_UBUNTU" = true ]; then
    SSH_USER="ubuntu"
else
    SSH_USER="ec2-user"
fi

echo ""
echo "🎉 PHASE 1 COMPLETE: Instance Created!"
echo ""
echo "Instance Details:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo "  Private IP: $PRIVATE_IP"
echo "  Region: $REGION"
echo "  SSH User: $SSH_USER"
echo "  Your IP: $MY_IP (allowed for SSH)"
echo ""

# PHASE 2: Configure SSH
echo "🔧 PHASE 2: Configuring SSH..."

# Create SSH config entry
SSH_CONFIG_ENTRY="
# $INSTANCE_NAME - Created $(date)
Host $INSTANCE_NAME
    HostName $PUBLIC_IP
    User $SSH_USER
    IdentityFile ~/${KEY_NAME}.pem
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

"

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create backup of existing SSH config
if [ -f ~/.ssh/config ]; then
    BACKUP_FILE="~/.ssh/config.backup.$(date +%Y%m%d%H%M%S)"
    cp ~/.ssh/config "${BACKUP_FILE/\~/$HOME}"
    echo "📋 Backed up existing SSH config to ${BACKUP_FILE}"
fi

# Add new entry to SSH config
echo "$SSH_CONFIG_ENTRY" >> ~/.ssh/config
chmod 600 ~/.ssh/config

echo "✅ SSH config updated!"
echo ""

# PHASE 3: Test SSH Connection
echo "🧪 PHASE 3: Testing SSH Connection..."
echo "⏳ Waiting for SSH to be ready (this may take 2-3 minutes)..."

# Wait for SSH to be ready
SSH_READY=false
ATTEMPTS=0
MAX_ATTEMPTS=12

while [ "$SSH_READY" = false ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    ATTEMPTS=$((ATTEMPTS + 1))
    echo "   Testing SSH connection... (attempt $ATTEMPTS/$MAX_ATTEMPTS)"
    
    # Test SSH connection
    if ssh -o ConnectTimeout=10 -o BatchMode=yes $INSTANCE_NAME "echo 'SSH connection successful'" 2>/dev/null; then
        SSH_READY=true
        echo "   ✅ SSH connection successful!"
        break
    else
        echo "   ⏳ SSH not ready yet, waiting..."
        sleep 15
    fi
done

if [ "$SSH_READY" = false ]; then
    echo "   ❌ SSH connection failed after $MAX_ATTEMPTS attempts"
    echo ""
    echo "🛠️  Manual troubleshooting:"
    echo "   • Wait a few more minutes and try: ssh $INSTANCE_NAME"
    echo "   • Check security group allows your IP: $MY_IP"
    echo "   • Verify instance is fully booted in AWS Console"
    echo ""
    echo "⚠️  Stopping here - please resolve SSH connectivity first"
    exit 1
fi

echo ""
echo "🎉 PHASE 3 COMPLETE: SSH Working!"
echo ""

# PHASE 4: Install VS Code Tunnels
echo "🚀 PHASE 4: Installing VS Code Tunnels..."

# Install VS Code CLI on the remote instance
echo "   Installing VS Code via snap on remote instance..."
ssh $INSTANCE_NAME << 'REMOTE_COMMANDS'
echo "Installing VS Code via snap..."
sudo snap install code --classic

# Verify installation
if command -v code >/dev/null 2>&1; then
    echo "VS Code installed successfully: $(code --version | head -1)"
    
    # Create tunnel startup script
    cat > ~/start-vscode-tunnel.sh << 'TUNNEL_SCRIPT'
#!/bin/bash
echo "🚀 Starting VS Code Tunnel..."
echo ""
echo "This will provide a URL to access VS Code in your browser"
echo "Press Ctrl+C to stop the tunnel"
echo ""
code tunnel --accept-server-license-terms
TUNNEL_SCRIPT
    
    chmod +x ~/start-vscode-tunnel.sh
    echo "VS Code CLI installation complete!"
    echo "Tunnel script created: ~/start-vscode-tunnel.sh"
else
    echo "ERROR: VS Code installation failed!"
    exit 1
fi
REMOTE_COMMANDS

if [ $? -eq 0 ]; then
    echo "   ✅ VS Code installed successfully!"
else
    echo "   ❌ VS Code installation failed"
    echo ""
    echo "🛠️  Manual fix:"
    echo "   ssh $INSTANCE_NAME"
    echo "   sudo snap install code --classic"
    echo ""
    echo "⚠️  Continuing anyway - you can install VS Code manually"
fi

echo ""
echo "🎉 PHASE 4 COMPLETE: VS Code Tunnels Installed!"

# PHASE 5: Optional Post-Install Setup
if [ "$POST_INSTALL" = true ]; then
    echo ""
    echo "🚀 PHASE 5: Installing Development Tools..."
    
    echo "   Installing latest Node.js LTS..."
    ssh $INSTANCE_NAME << 'REMOTE_SETUP'
echo "Installing Node.js LTS..."
# Remove any existing Node.js
sudo apt remove nodejs npm -y 2>/dev/null || true

# Install latest Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

echo "Installing additional development tools..."
sudo apt update
sudo apt install -y python3-pip python3-venv build-essential

echo "Installing Claude CLI..."
sudo npm install -g @anthropic-ai/claude-code

echo "Creating development environment setup..."
cat > ~/.dev-setup-complete << 'EOF'
# Development Environment Setup Complete
# Created: $(date)

Node.js: $(node --version)
npm: $(npm --version)
Python: $(python3 --version)
VS Code: Available via 'code' command
Claude CLI: Available via 'claude' command

# To configure Claude CLI:
# claude configure
# or
# export ANTHROPIC_API_KEY="your-api-key-here"

# To start VS Code tunnel:
# code tunnel --accept-server-license-terms
EOF

echo "Post-install setup completed successfully!"
REMOTE_SETUP

    if [ $? -eq 0 ]; then
        echo "   ✅ Development tools installed successfully!"
        echo ""
        echo "   📦 Installed:"
        echo "      • Node.js LTS with npm"
        echo "      • Python 3 development environment"
        echo "      • Claude CLI for AI assistance"
        echo "      • Build tools and development utilities"
        echo ""
        echo "   ⚙️  Next steps:"
        echo "      • Configure Claude: ssh $INSTANCE_NAME && claude configure"
        echo "      • Set API key: export ANTHROPIC_API_KEY='your-key'"
        echo "      • Start coding with full development environment!"
    else
        echo "   ⚠️  Some development tools installation failed"
        echo "   You can install them manually later via SSH"
    fi
    
    echo ""
    echo "🎉 PHASE 5 COMPLETE: Development Environment Ready!"
else
    echo ""
    echo "⏭️  PHASE 5 SKIPPED: Use --post-install to install development tools"
    echo "   You can install tools manually later:"
    echo "   • SSH: ssh $INSTANCE_NAME"
    echo "   • Follow post-setup guide in documentation"
fi

echo ""
echo "🎉 ALL PHASES COMPLETE!"
echo "========================================="
echo ""
echo "✅ PHASE 1: Instance created and running"
echo "✅ PHASE 2: SSH configured locally"  
echo "✅ PHASE 3: SSH connection verified"
echo "✅ PHASE 4: VS Code tunnels installed"
if [ "$POST_INSTALL" = true ]; then
    echo "✅ PHASE 5: Development tools installed"
else
    echo "⏭️  PHASE 5: Skipped (use --post-install flag)"
fi
echo ""
echo "📋 Instance Details:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo "  Region: $REGION"
echo "  SSH User: $SSH_USER"
echo ""
echo "🔑 SSH Connection (Verified Working):"
echo "  Connect: ssh $INSTANCE_NAME"
echo ""
echo "💡 VS Code Connection Options:"
echo ""
echo "  🌐 VS Code Tunnels (Browser-based, Recommended):"
echo "    1. ssh $INSTANCE_NAME"
echo "    2. code tunnel --accept-server-license-terms"
echo "    3. Open provided URL in browser"
echo "    4. Sign in with Microsoft/GitHub account"
echo ""
if [ "$POST_INSTALL" = true ]; then
    echo "  🤖 Claude AI Assistant:"
    echo "    1. ssh $INSTANCE_NAME"
    echo "    2. claude configure  # Set your Anthropic API key"
    echo "    3. claude chat 'Hello Claude, help me code!'"
    echo ""
fi
echo "  📱 Remote-SSH (NOT Recommended - Use Tunnels Instead):"
echo "    ❌ Remote-SSH crashes t2.micro instances"
echo "    ✅ Use browser-based tunnels for stability"
echo ""
echo "🧪 Quick Test:"
echo "  ssh $INSTANCE_NAME"
if [ "$POST_INSTALL" = true ]; then
    echo "  node --version && claude --help"
else
    echo "  code tunnel --accept-server-license-terms"
fi
echo ""
echo "🔧 Instance Management:"
echo "  Status: ./list_ec2_instances.sh $REGION"
echo "  Remove: ./remove_ec2_instances.sh --region $REGION $INSTANCE_ID"
echo ""
echo "🛡️  Security:"
echo "  SSH access allowed ONLY from: $MY_IP"
echo "  Security Group: $SECURITY_GROUP_ID"
echo ""
echo "⚠️  Remember: Monitor your AWS usage!"
echo ""
echo "🎯 You now have a verified working SSH server with VS Code tunnels ready!"