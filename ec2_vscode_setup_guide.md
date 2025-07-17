# Complete EC2 + VS Code Remote Setup Guide (SSH-Only)

## Quick Start Summary

This guide shows you how to create a secure EC2 instance that you can connect to from VS Code using direct SSH - simple, reliable, and fast.

**What you'll get:**
- ✅ **Direct SSH connection** with IP restrictions
- ✅ **Automatic SSH configuration**
- ✅ **Full VS Code Remote functionality**
- ✅ **Clean development environment with Ubuntu**
- ✅ **Pre-installed development tools**

**Security benefits:**
- SSH access only from your specific IP address
- Key-based authentication (no passwords)
- Simple, reliable connection method
- Standard SSH security practices

---

## Prerequisites

### 1. Install Required Tools

**AWS CLI:**
```bash
# macOS (using Homebrew)
brew install awscli

# Or download installer from: https://awscli.amazonaws.com/AWSCLIV2.pkg
```

### 2. Configure AWS Credentials

**Set up AWS CLI:**
```bash
aws configure
```

Enter:
- **AWS Access Key ID**: Your IAM user access key
- **AWS Secret Access Key**: Your IAM user secret key
- **Default region**: `us-east-1` (or your preferred region)
- **Default output format**: `json`

**Test credentials:**
```bash
aws sts get-caller-identity
```

### 3. Get Your Public IP Address

```bash
curl ifconfig.me
```

You'll need this IP address for the setup script.

---

## Step 1: Create EC2 Instance

### 1.1 Make Scripts Executable

```bash
chmod +x ec2_ssh_only_setup.sh
chmod +x list_ec2_instances.sh
chmod +x remove_ec2_instances.sh
```

### 1.2 Create Instance with Your IP

```bash
# Replace YOUR_IP with your actual IP from step 3 above
./ec2_ssh_only_setup.sh --region eu-west-1 --my-ip YOUR_IP --name "my-dev-server"
```

**Example:**
```bash
./ec2_ssh_only_setup.sh --region eu-west-1 --my-ip 203.0.113.42 --name "trading-dev"
```

### 1.3 Wait for Instance to Be Ready

The script will:
- Create security group allowing SSH only from your IP
- Launch Ubuntu 22.04 instance with development tools
- Generate SSH key pair automatically
- Configure your ~/.ssh/config file automatically
- Show you connection details

**Example output:**
```
🎉 Setup complete! Your SSH-only EC2 instance is ready.

Instance Details:
  Instance ID: i-1234567890abcdef0
  Public IP: 34.245.77.208
  Your IP: 203.0.113.42 (allowed for SSH)

✅ SSH config updated!

🔑 SSH Connection:
  Connect: ssh my-dev-server

📱 To connect with VS Code:
1. Enable Remote-SSH extension (if prompted)
2. Command Palette (Cmd+Shift+P)
3. Type: 'Remote-SSH: Connect to Host'
4. Select: my-dev-server
```

---

## Step 2: Test Connection

### 2.1 Test SSH Connection

```bash
# Test direct SSH connection (replace with your server name)
ssh my-dev-server
```

**Expected result:** You should get a Ubuntu prompt with a welcome message.

**If this fails:**
- Check your IP hasn't changed: `curl ifconfig.me`
- Verify the key file exists: `ls -la ssh-key-*.pem`
- Check SSH config was created: `cat ~/.ssh/config`

---

## Step 3: Connect VS Code

### 3.1 Install Required VS Code Extension

In VS Code, install:
- **"Remote - SSH"** by Microsoft

**Important:** Do NOT use AWS Toolkit for connections.

### 3.2 Connect to Instance

1. **Open VS Code**
2. **Enable Remote-SSH** if prompted (click "Enable and Reload")
3. **Command Palette** (`Cmd+Shift+P` or `Ctrl+Shift+P`)
4. **Type:** "Remote-SSH: Connect to Host"
5. **Select:** your server name (e.g., `my-dev-server`)
6. **Choose:** Linux as the platform
7. **Wait** for VS Code to install the remote server

### 3.3 Verify Connection

You should see:
- Bottom left corner shows: `SSH: my-dev-server`
- New VS Code window opens
- File explorer shows the Ubuntu instance file system
- Terminal shows Ubuntu prompt: `ubuntu@i-xxxxxxxxx:~$`

---

## Management Commands

### List All Instances

```bash
# List instances in specific region
./list_ec2_instances.sh eu-west-1

# List instances in default region (us-east-1)
./list_ec2_instances.sh
```

### Remove Instances

```bash
# Remove specific instance
./remove_ec2_instances.sh --region eu-west-1 i-your-instance-id

# Remove multiple instances
./remove_ec2_instances.sh --region eu-west-1 i-instance1 i-instance2
```

### Check Instance Status

```bash
# Check if instance is running
aws ec2 describe-instances --instance-ids i-your-instance-id --region eu-west-1
```

---

## Script Options

### ec2_ssh_only_setup.sh Options

```bash
# All available options
./ec2_ssh_only_setup.sh --help

# Common usage patterns
./ec2_ssh_only_setup.sh --region eu-west-1 --my-ip 203.0.113.42 --name "dev-server"
./ec2_ssh_only_setup.sh -r us-west-2 -i 198.51.100.10 -n "coding-box" -k "my-key"
```

**Options:**
- `-r, --region` - AWS region (default: us-east-1)
- `-i, --my-ip` - Your public IP address (required)
- `-n, --name` - Server name (default: ssh-dev-instance)
- `-k, --key-name` - SSH key name (default: auto-generated)

---

## Troubleshooting

### Common Issues and Solutions

**1. "Permission denied (publickey)"**
- Check key file exists: `ls -la ssh-key-*.pem`
- Verify SSH config: `cat ~/.ssh/config`
- Test key permissions: `chmod 600 ssh-key-*.pem`

**2. "Connection refused" or "Connection timeout"**
- Check your IP hasn't changed: `curl ifconfig.me`
- Verify security group allows your current IP
- Wait a few minutes for instance to fully boot

**3. "Host key verification failed"**
- Remove old host key: `ssh-keygen -R your-server-name`
- Or use the config setting: `StrictHostKeyChecking no`

**4. VS Code connection fails**
- Ensure Remote-SSH extension is enabled
- Try connecting via SSH first: `ssh my-dev-server`
- Check VS Code isn't using AWS Toolkit for connection

**5. "Could not establish connection"**
- Instance might be too small (t2.micro) for VS Code Server
- Try connecting multiple times - first connection can be slow
- Check instance has enough free space: `df -h`

**6. IP address changed**
- Get new IP: `curl ifconfig.me`
- Update security group or recreate instance with new IP

### Debug SSH Issues

```bash
# Verbose SSH connection to see what's happening
ssh -v my-dev-server

# Check SSH config
cat ~/.ssh/config

# Test SSH config syntax
ssh -G my-dev-server
```

---

## Important Notes

### Security Best Practices

- **Never use root user credentials** - always use IAM users
- **Keep your IP updated** - script restricts access to your specific IP
- **Monitor your instances** - don't leave them running unnecessarily
- **Use unique key names** - avoid conflicts with existing keys

### Cost Management

- **t2.micro instances are free tier eligible**
- **Remember to terminate instances** when not needed
- **Use the remove script** to clean up: `./remove_ec2_instances.sh`

### Why SSH-Only is Better

**Advantages over other approaches:**
- ✅ **Simple and reliable** - standard SSH connection
- ✅ **Better VS Code compatibility** - no proxy complications
- ✅ **Faster connections** - no proxy overhead
- ✅ **Standard debugging** - familiar SSH tools work
- ✅ **Automatic configuration** - script sets everything up

**Security:**
- SSH access restricted to your IP only
- Key-based authentication
- No complex proxy setups to break
- Standard SSH security practices

---

## What This Setup Achieves

### Development Benefits

- **Full VS Code Remote functionality**
- **File synchronization** between local and remote
- **Remote terminal** access
- **Extension support** on remote instance
- **Port forwarding** for web development
- **Integrated debugging** on remote instance

### Architecture

```
VS Code → SSH → EC2 Instance
```

- **VS Code Remote-SSH** handles the editor connection
- **Direct SSH** provides reliable, fast connection
- **IP restrictions** ensure security
- **No proxy complexity** - simple and reliable

### Pre-installed Tools

Your instance comes with:
- **Ubuntu 22.04 LTS** (latest stable)
- **Node.js LTS** and npm
- **Python 3** and pip
- **Docker CE** (ready to use)
- **Git, vim, htop** and development tools
- **VS Code CLI** (pre-installed)
- **Build tools** and compilers

---

## Quick Reference

### Essential Commands

```bash
# Get your IP
curl ifconfig.me

# Create instance
./ec2_ssh_only_setup.sh --region eu-west-1 --my-ip YOUR_IP --name "my-server"

# Test connection
ssh my-server

# List instances
./list_ec2_instances.sh eu-west-1

# Remove instance
./remove_ec2_instances.sh --region eu-west-1 i-instance-id
```

### VS Code Connection

1. **Command Palette** (`Cmd+Shift+P`)
2. **"Remote-SSH: Connect to Host"**
3. **Select your server**
4. **Choose Linux**
5. **Start coding!**

### File Locations

- **SSH Config:** `~/.ssh/config` (auto-configured)
- **Key Files:** `~/ssh-key-YYYYMMDDHHMM.pem` (auto-generated)
- **Scripts:** `./ec2_ssh_only_setup.sh`, `./list_ec2_instances.sh`, `./remove_ec2_instances.sh`

Happy coding! 🚀

---

## Changelog

### v2.0 - SSH-Only Approach
- Removed SSM complexity
- Added automatic SSH config generation
- Simplified connection process
- Improved reliability
- Added IP-based security restrictions

### v1.0 - SSM Approach (Deprecated)
- Used SSM for connections (unreliable)
- Complex proxy setup
- Frequent connection issues