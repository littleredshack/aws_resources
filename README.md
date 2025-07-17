# EC2 + VS Code Remote Setup (Tested & Working)

**A reliable, battle-tested solution for EC2 development with VS Code tunnels - no more Remote-SSH crashes!**

## 🚀 What This Provides

- **Stable EC2 instances** that won't crash during development
- **VS Code Tunnels** for browser-based development (much more reliable than Remote-SSH)  
- **Phased setup approach** with verification at each step
- **Automatic SSH configuration** for emergency/admin access
- **Complete resource cleanup** when removing instances
- **IP-restricted security** (only your IP can access)

## 🌐 Before You Start - Get Your Public IP

**You'll need your current public IP address for security configuration:**

```bash
# Method 1: Using curl (sometimes returns hex format)
curl ifconfig.me

# Method 2: Using a different service  
curl ipinfo.io/ip

# Method 3: Check via web browser
# Visit: https://whatsmyip.com or https://ipinfo.io
```

**Note:** If `curl ifconfig.me` returns a hex value instead of normal IP format (like `200.5.49.46`), use one of the other methods or the web browser option.

**Important:** Only this IP address will be able to SSH to your instance for security.

## ⚡ Why This Works (Lessons Learned)

**❌ What Crashes Instances:**
- **VS Code Remote-SSH** on t2.micro - consistently crashes after 2-3 hours
- **Heavy user data scripts** - cause dpkg errors and package conflicts during boot
- **Auto-installing Docker/Node.js** - overwhelms 1GB RAM instances

**✅ What Actually Works:**
- **VS Code Tunnels** - browser-based, stable, full functionality
- **Minimal user data** - only essential tools (git, vim, htop), fast reliable boot
- **Post-creation setup** - install tools after basic connectivity verified
- **Phased verification** - test each step before proceeding, catch failures early

## 🏃‍♂️ Complete Setup Process

**1. Create instance:**
```bash
curl ifconfig.me
./ec2_ssh_only_setup_v2.sh --region eu-west-1 --my-ip YOUR_IP --name "my-dev"
```

**2. Alternative - Full automatic setup:**
```bash
# Everything automated in one command (includes persistent tunnel)
./ec2_ssh_only_setup_v2.sh --region eu-west-1 --my-ip YOUR_IP --name "dev-server" --key-name "dev-$(date +%Y%m%d%H%M)" --post-install
```

**3. Open tunnel URL in browser:**
- Full VS Code interface
- Integrated terminal
- No crashes, no Remote-SSH issues

## 📁 Files in This Repository

- **`ec2_ssh_only_setup_v2.sh`** - Main instance creation with phased approach (t2.small default)
- **`setup_tunnel_service.sh`** - Sets up persistent VS Code tunnel service
- **`list_ec2_instances.sh`** - List instances across regions
- **`remove_ec2_instances.sh`** - Complete cleanup of instances and resources
- **`list_all_aws_resources.sh`** - Comprehensive AWS resource inventory
- **`monitor_instance.sh`** - Real-time monitoring (prevents crashes)
- **`ec2_vscode_setup_guide.md`** - Detailed setup guide with troubleshooting
- **`README.md`** - This file

## 🔧 Management & Monitoring

```bash
# List instances
./list_ec2_instances.sh eu-west-1

# Monitor instance health (prevent crashes)
./monitor_instance.sh stable-dev

# Complete cleanup when done
./remove_ec2_instances.sh --region eu-west-1 i-instance-id

# List all AWS resources
./list_all_aws_resources.sh eu-west-1
```

## 🧪 Phased Setup Approach

**🎯 PHASE 1: Create Instance**
- Minimal Ubuntu 22.04 with essential tools only
- No heavy packages that cause conflicts

**🔧 PHASE 2: Configure SSH**  
- Automatic SSH config generation
- Backup of existing config

**🧪 PHASE 3: Test SSH (CRITICAL)**
- Verifies connectivity before proceeding
- Stops if SSH fails - no broken setups

**🚀 PHASE 4: Install VS Code**
- Only after SSH verified working
- Uses snap for reliability

**🛠️ PHASE 5: Post-Install (Optional)**
- Node.js, Claude CLI, development tools
- Only with --post-install flag

**⚙️ PHASE 6: Persistent Tunnel**
- Systemd service for auto-start
- Survives reboots, auto-restarts

## 🔒 VS Code Tunnel Security

**⚠️ Important:** Anyone with your tunnel URL can attempt to connect. Here's how to keep it secure:

### **🛡️ Built-in Protection:**
- **Microsoft/GitHub authentication required** - anonymous users can't access
- **Account-based access control** - only authenticated users can connect
- **Encrypted tunnel connection** - all traffic is secured end-to-end

### **⚠️ Security Considerations:**
- **Anyone with the URL** can attempt to connect
- **Shared/compromised accounts** could access your environment
- **No IP restrictions** on the tunnel URL itself (bypasses EC2 security groups)
- **URL acts like a password** - treat it as sensitive information

### **🔐 How to Secure Your Tunnel:**

**1. Use Strong Authentication:**
```bash
# Use dedicated account for development
# - Create separate GitHub account for coding projects
# - Use strong, unique password + 2FA
# - Don't share account credentials
```

**2. Monitor Access:**
```bash
# Check tunnel connection logs
ssh your-instance "sudo journalctl -u vscode-tunnel.service | grep -i 'connect\|auth'"

# Monitor active connections
ssh your-instance "sudo netstat -an | grep ESTABLISHED"

# In VS Code: View → Command Palette → "Remote-Tunnels: Show Log"
```

**3. Rotate Tunnel URLs:**
```bash
# Get new tunnel URL by restarting service
ssh your-instance "sudo systemctl restart vscode-tunnel.service"

# Or using management script
./setup_tunnel_service.sh your-instance --restart
./setup_tunnel_service.sh your-instance --url
```

**4. Instance-Level Security:**
```bash
# Your EC2 instance is IP-restricted for SSH
# But tunnel traffic goes through Microsoft's servers
# Additional monitoring recommended:
./monitor_instance.sh your-instance
```

### **🚨 Security Best Practices:**

- ✅ **Never share tunnel URLs** in git repos, chat, or public forums
- ✅ **Use dedicated GitHub/Microsoft account** for development only
- ✅ **Enable 2FA** on your authentication account
- ✅ **Monitor tunnel logs** for unexpected connections
- ✅ **Restart tunnel periodically** to invalidate old URLs
- ✅ **Keep sensitive data secure** (use env vars for API keys)
- ✅ **Don't store credentials** in plain text files
- ✅ **Use private/incognito browser** for tunnel access

### **🔍 Security Monitoring:**

```bash
# Monitor for unusual activity
./monitor_instance.sh your-instance logs

# Check who's accessing your files
ssh your-instance "sudo auditctl -w /home/ubuntu -p rwxa"

# Monitor system resources for unexpected usage
ssh your-instance "htop"
```

### **🛡️ If Security is Critical:**

**Consider these alternatives for maximum security:**
- **Local VS Code with SSH** (despite Remote-SSH stability issues)
- **VPN to your instance** instead of public tunnels
- **Bastion host setup** with additional network security layers
- **Private tunnel services** (more complex but more secure)

**Remember: Treat your tunnel URL like a password - never share it publicly!** 🔐

---

## **Simple Architecture:**
```
Your Browser → VS Code Tunnel → EC2 Instance
     ↓
Local SSH (backup/admin access)
```

- **VS Code Tunnels** provide browser-based development
- **Direct SSH** for administration and setup
- **No complex proxies** or middleware
- **IP-restricted security** - only your IP can connect

## 💰 Cost Information

**Free Tier Eligible:**
- t2.small: ~$17/month (much more reliable than "free" t2.micro that constantly crashes)

**Cost Optimization:**
- Stop instances when not in use
- Use remove script for complete cleanup

## 🐛 Common Issues

- **"Permission denied"** - Check IP: `curl ifconfig.me`, update security group
- **"Connection refused"** - Wait 2-3 minutes for instance boot
- **Tunnel auth fails** - Use incognito browser window
- **Instance crashes** - You probably used Remote-SSH (use tunnels instead!)

See the [complete troubleshooting guide](ec2_vscode_setup_guide.md#troubleshooting) for solutions.

## 🤝 Contributing

Found an issue? This guide is based on real testing and troubleshooting. Please open issues for:
- Script improvements
- Additional troubleshooting scenarios  
- Cost optimization tips
- Security enhancements

## 📄 License

MIT License - use and modify as needed.

---

**Battle-tested and reliable!** This approach has been thoroughly tested and documented based on real usage and troubleshooting. 🚀