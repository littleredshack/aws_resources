# EC2 + VS Code Remote Setup with SSM

A complete, secure solution for setting up EC2 development instances that you can connect to from VS Code using AWS Systems Manager (SSM) - no open SSH ports required!

## 🚀 What This Provides

- **Secure EC2 instances** with no open SSH ports
- **VS Code Remote development** through encrypted SSM tunnels
- **Automated setup scripts** for quick deployment
- **Ubuntu 22.04** with all development tools pre-installed
- **Complete troubleshooting guide** for common issues

## 🔒 Security Features

- ✅ **No direct SSH access** from the internet
- ✅ **All traffic encrypted** through AWS SSM
- ✅ **AWS credential authentication** (no passwords)
- ✅ **No public IP dependencies**
- ✅ **Audit trail** through CloudTrail

## 📋 Prerequisites

- AWS CLI installed and configured
- AWS Session Manager plugin installed
- VS Code with Remote-SSH extension
- Appropriate IAM permissions for EC2, IAM, and SSM

## 🏃‍♂️ Quick Start

1. **Create an EC2 instance:**
   ```bash
   ./ec2_ssm_setup.sh --region eu-west-1 --name "my-dev-server" --key-name "my-key-$(date +%Y%m%d)"
   ```

2. **Configure SSH:**
   ```bash
   nano ~/.ssh/config
   ```
   Add the configuration from the setup guide.

3. **Connect with VS Code:**
   - Command Palette → "Remote-SSH: Connect to Host"
   - Select your configured host

## 📁 Files in This Repository

- **`ec2_ssm_setup.sh`** - Main script to create EC2 instances with SSM access
- **`list_ec2_instances.sh`** - List all EC2 instances in a region
- **`remove_ec2_instances.sh`** - Safely remove EC2 instances
- **`ec2_vscode_setup_guide.md`** - Complete step-by-step setup guide
- **`README.md`** - This file

## 📖 Documentation

**[Complete Setup Guide](ec2_vscode_setup_guide.md)** - Detailed walkthrough with all commands and troubleshooting

## ⚠️ Important Warnings

- **NEVER use AWS Toolkit for EC2 connections** - it breaks SSH configs
- **Always use Remote-SSH extension** instead
- **Use unique key names** to avoid conflicts
- **Don't let VS Code edit SSH config** - click "Cancel" when asked

## 🛠️ Management Commands

```bash
# List instances
./list_ec2_instances.sh eu-west-1

# Remove instances
./remove_ec2_instances.sh --region eu-west-1 i-instance-id

# Connect via SSM directly
aws ssm start-session --target i-instance-id --region eu-west-1
```

## 🐛 Common Issues

- **"Permission denied (publickey)"** - Check SSH key path and permissions
- **"Session Manager plugin not found"** - Install the plugin
- **"Too many authentication failures"** - Add `IdentitiesOnly yes` to SSH config
- **AWS Toolkit breaks connection** - Restore SSH config manually

See the [complete troubleshooting guide](SETUP_GUIDE.md#troubleshooting) for solutions.

## 🏗️ Architecture

```
VS Code → SSH → ProxyCommand → SSM → EC2 Instance
```

- VS Code Remote-SSH handles the editor connection
- SSH Config routes through SSM proxy
- SSM provides secure tunnel to EC2
- No direct networking required

## 🤝 Contributing

Found an issue or improvement? Please open an issue or submit a pull request!

## 📄 License

MIT License - feel free to use and modify as needed.

---

**Happy secure coding!** 🚀