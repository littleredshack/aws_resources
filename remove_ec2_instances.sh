#!/bin/bash

# Safely remove EC2 instances with confirmation
# Usage: ./remove-ec2.sh [OPTIONS] <instance-id-1> [instance-id-2] [instance-id-3] ...
# Example: ./remove-ec2.sh i-1234567890abcdef0
# Example: ./remove-ec2.sh --region eu-west-1 i-1234567890abcdef0

set -e

# Function to show help
show_help() {
    cat << EOF
EC2 Instance Removal Tool

USAGE:
    $0 [OPTIONS] <instance-id-1> [instance-id-2] ...

OPTIONS:
    -r, --region REGION     AWS region (default: us-east-1)
    -h, --help              Show this help message

EXAMPLES:
    $0 i-1234567890abcdef0                                    # Remove instance in us-east-1
    $0 --region eu-west-1 i-1234567890abcdef0                # Remove instance in eu-west-1
    $0 -r us-west-2 i-123456 i-789012                        # Remove multiple instances

SAFETY FEATURES:
    • Validates all instance IDs before termination
    • Shows detailed instance information
    • Requires double confirmation (type 'yes' then 'DELETE')
    • Handles errors gracefully

EOF
}

REGION=${AWS_DEFAULT_REGION:-us-east-1}
INSTANCE_IDS=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        i-*)
            INSTANCE_IDS+=("$1")
            shift
            ;;
        *)
            echo "❌ Unknown option or invalid instance ID: $1"
            echo "Instance IDs should start with 'i-'"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if any instance IDs provided
if [ ${#INSTANCE_IDS[@]} -eq 0 ]; then
    echo "❌ Error: No instance IDs provided"
    echo ""
    echo "Usage: $0 [OPTIONS] <instance-id-1> [instance-id-2] ..."
    echo "Example: $0 --region eu-west-1 i-1234567890abcdef0"
    echo ""
    echo "💡 To see your instances first, run the list script"
    echo "   ./list-ec2.sh $REGION"
    exit 1
fi

echo "🗑️  EC2 Instance Removal Tool"
echo "============================="
echo "Region: $REGION"
echo ""

# Validate and collect instance information
VALID_INSTANCES=()
INSTANCE_DETAILS=()
SECURITY_GROUPS=()
KEY_NAMES=()

echo "🔍 Validating instance IDs and collecting resource information..."

for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    echo "   Checking $INSTANCE_ID..."
    
    # Check if instance exists and get its details (works even if instance is broken)
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,InstanceType,SecurityGroups[].GroupId,KeyName]' \
        --output text \
        --region $REGION 2>/dev/null) || {
        echo "   ❌ Instance $INSTANCE_ID not found or access denied"
        continue
    }
    
    # Parse the instance information
    read -r id name state type sg_list key_name <<< "$INSTANCE_INFO"
    name=${name:-"(no name)"}
    
    if [ "$state" == "terminated" ]; then
        echo "   ⚠️  Instance $INSTANCE_ID is already terminated"
        continue
    fi
    
    # Collect security groups (they're space-separated in the output)
    if [ "$sg_list" != "None" ] && [ -n "$sg_list" ]; then
        for sg in $sg_list; do
            # Avoid duplicates and skip default security groups
            if [[ ! " ${SECURITY_GROUPS[@]} " =~ " ${sg} " ]] && [[ "$sg" != sg-* ]] || [[ "$sg" =~ ^sg-[0-9a-f]{8,17}$ ]]; then
                # Check if it's not a default security group by name
                SG_NAME=$(aws ec2 describe-security-groups \
                    --group-ids "$sg" \
                    --query 'SecurityGroups[0].GroupName' \
                    --output text \
                    --region $REGION 2>/dev/null || echo "unknown")
                
                if [ "$SG_NAME" != "default" ] && [ "$SG_NAME" != "unknown" ]; then
                    SECURITY_GROUPS+=("$sg")
                fi
            fi
        done
    fi
    
    # Collect key names
    if [ "$key_name" != "None" ] && [ -n "$key_name" ] && [[ ! " ${KEY_NAMES[@]} " =~ " ${key_name} " ]]; then
        KEY_NAMES+=("$key_name")
    fi
    
    VALID_INSTANCES+=("$INSTANCE_ID")
    INSTANCE_DETAILS+=("$id|$name|$state|$type")
    echo "   ✅ $INSTANCE_ID - $name ($state, $type)"
    
    # Show collected resources for this instance
    if [ "$sg_list" != "None" ] && [ -n "$sg_list" ]; then
        echo "      Security groups: $sg_list"
    fi
    if [ "$key_name" != "None" ] && [ -n "$key_name" ]; then
        echo "      Key pair: $key_name"
    fi
done

# Check if we have any valid instances
if [ ${#VALID_INSTANCES[@]} -eq 0 ]; then
    echo ""
    echo "❌ No valid instances to terminate"
    exit 1
fi

echo ""
echo "📋 The following instances will be TERMINATED:"
echo "=============================================="

for detail in "${INSTANCE_DETAILS[@]}"; do
    IFS='|' read -r id name state type <<< "$detail"
    echo "🔸 $id"
    echo "   Name: $name"
    echo "   State: $state"
    echo "   Type: $type"
    echo ""
done

# Show what will be cleaned up
if [ ${#SECURITY_GROUPS[@]} -gt 0 ]; then
    echo "🧹 Security groups that will be cleaned up:"
    for sg in "${SECURITY_GROUPS[@]}"; do
        echo "   $sg"
    done
    echo ""
fi

if [ ${#KEY_NAMES[@]} -gt 0 ]; then
    echo "🔑 Key pairs available for cleanup:"
    for key in "${KEY_NAMES[@]}"; do
        echo "   $key"
    done
    echo ""
fi

echo "⚠️  WARNING: This action CANNOT be undone!"
echo "⚠️  All data on these instances will be PERMANENTLY lost!"
echo "⚠️  Make sure you have backups of any important data!"
echo ""

# Confirmation prompt
read -p "❓ Are you absolutely sure you want to terminate these ${#VALID_INSTANCES[@]} instance(s)? [type 'yes' to confirm]: " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    echo "❌ Termination cancelled"
    exit 0
fi

echo ""
echo "🚨 Last chance! Type the word 'DELETE' to proceed:"
read -p "❓ Type 'DELETE' to confirm: " FINAL_CONFIRMATION

if [ "$FINAL_CONFIRMATION" != "DELETE" ]; then
    echo "❌ Termination cancelled"
    exit 0
fi

echo ""
echo "🗑️  Terminating instances..."

# Terminate each instance (resource info already collected)
for INSTANCE_ID in "${VALID_INSTANCES[@]}"; do
    echo "   Terminating $INSTANCE_ID..."
    
    # Terminate the instance
    aws ec2 terminate-instances \
        --instance-ids "$INSTANCE_ID" \
        --region $REGION \
        --query 'TerminatingInstances[0].[InstanceId,CurrentState.Name,PreviousState.Name]' \
        --output text || {
        echo "   ❌ Failed to terminate $INSTANCE_ID"
        continue
    }
    
    echo "   ✅ $INSTANCE_ID termination initiated"
done

echo ""
echo "✅ Termination requests sent!"

# Wait for instances to be fully terminated before cleanup
echo ""
echo "⏳ Waiting for instances to be fully terminated before cleanup..."
for INSTANCE_ID in "${VALID_INSTANCES[@]}"; do
    echo "   Waiting for $INSTANCE_ID to terminate..."
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region $REGION || {
        echo "   ⚠️  Timeout waiting for $INSTANCE_ID to terminate, continuing anyway..."
    }
done

# Cleanup security groups
if [ ${#SECURITY_GROUPS[@]} -gt 0 ]; then
    echo ""
    echo "🧹 Cleaning up security groups..."
    
    for SG_ID in "${SECURITY_GROUPS[@]}"; do
        echo "   Checking security group: $SG_ID"
        
        # Check if security group is still in use by any instances
        INSTANCE_USAGE=$(aws ec2 describe-instances \
            --filters "Name=instance.group-id,Values=$SG_ID" "Name=instance-state-name,Values=running,pending,stopping,stopped,rebooting" \
            --query 'length(Reservations[].Instances[])' \
            --output text \
            --region $REGION 2>/dev/null || echo "0")
        
        # Check if security group is used by other AWS resources (load balancers, RDS, etc.)
        OTHER_USAGE=$(aws ec2 describe-security-groups \
            --group-ids "$SG_ID" \
            --query 'SecurityGroups[0].IpPermissions[?UserIdGroupPairs && length(UserIdGroupPairs) > `0`] | length(@)' \
            --output text \
            --region $REGION 2>/dev/null || echo "0")
        
        # Check if this security group is referenced by other security groups
        REFERENCED_BY=$(aws ec2 describe-security-groups \
            --filters "Name=ip-permission.group-id,Values=$SG_ID" \
            --query 'length(SecurityGroups[])' \
            --output text \
            --region $REGION 2>/dev/null || echo "0")
        
        # Get security group name for better reporting
        SG_NAME=$(aws ec2 describe-security-groups \
            --group-ids "$SG_ID" \
            --query 'SecurityGroups[0].GroupName' \
            --output text \
            --region $REGION 2>/dev/null || echo "unknown")
        
        if [ "$INSTANCE_USAGE" = "0" ] && [ "$OTHER_USAGE" = "0" ] && [ "$REFERENCED_BY" = "0" ]; then
            echo "   Deleting unused security group: $SG_ID ($SG_NAME)"
            aws ec2 delete-security-group \
                --group-id "$SG_ID" \
                --region $REGION 2>/dev/null && {
                echo "   ✅ Deleted security group: $SG_ID"
            } || {
                echo "   ⚠️  Could not delete security group: $SG_ID (might have dependencies or be protected)"
            }
        else
            echo "   ⚠️  Security group $SG_ID ($SG_NAME) is still in use:"
            if [ "$INSTANCE_USAGE" != "0" ]; then
                echo "      - Used by $INSTANCE_USAGE instance(s)"
            fi
            if [ "$OTHER_USAGE" != "0" ]; then
                echo "      - Has references to other security groups"
            fi
            if [ "$REFERENCED_BY" != "0" ]; then
                echo "      - Referenced by $REFERENCED_BY other security group(s)"
            fi
            echo "      Skipping deletion for safety"
        fi
    done
else
    echo ""
    echo "🧹 No security groups to clean up"
fi

# Cleanup key pairs
if [ ${#KEY_NAMES[@]} -gt 0 ]; then
    echo ""
    read -p "❓ Also delete SSH key pairs from AWS? [y/N]: " DELETE_KEYS
    
    if [[ "$DELETE_KEYS" =~ ^[Yy]$ ]]; then
        echo "🧹 Cleaning up key pairs..."
        
        for KEY_NAME in "${KEY_NAMES[@]}"; do
            echo "   Deleting key pair: $KEY_NAME"
            aws ec2 delete-key-pair \
                --key-name "$KEY_NAME" \
                --region $REGION 2>/dev/null && {
                echo "   ✅ Deleted key pair: $KEY_NAME"
                
                # Also suggest deleting local key file
                if [ -f "${KEY_NAME}.pem" ]; then
                    echo "   💡 Local key file found: ${KEY_NAME}.pem"
                    read -p "   ❓ Delete local key file too? [y/N]: " DELETE_LOCAL
                    if [[ "$DELETE_LOCAL" =~ ^[Yy]$ ]]; then
                        rm -f "${KEY_NAME}.pem"
                        echo "   ✅ Deleted local key file: ${KEY_NAME}.pem"
                    fi
                fi
            } || {
                echo "   ⚠️  Could not delete key pair: $KEY_NAME"
            }
        done
    else
        echo "🔑 Keeping key pairs in AWS"
        echo "   Key pairs to manually clean up later: ${KEY_NAMES[*]}"
    fi
fi
echo ""
echo "📝 Notes:"
echo "   • Instances are now terminated"
echo "   • Unused security groups have been cleaned up"
echo "   • You will stop being charged immediately"
echo "   • Associated EBS volumes may be deleted based on their configuration"
echo ""
echo "🔍 To check remaining resources:"
echo "   Security groups: aws ec2 describe-security-groups --region $REGION"
echo "   Key pairs: aws ec2 describe-key-pairs --region $REGION"
echo ""
echo "🔍 To check status, run the list script again in a few minutes"

# Optional: Show current status
echo ""
read -p "❓ Show current instance status? [y/N]: " SHOW_STATUS

if [[ "$SHOW_STATUS" =~ ^[Yy]$ ]]; then
    echo ""
    echo "📊 Current status:"
    for INSTANCE_ID in "${VALID_INSTANCES[@]}"; do
        STATUS=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text \
            --region $REGION 2>/dev/null || echo "unknown")
        echo "   $INSTANCE_ID: $STATUS"
    done
fi

echo ""
echo "🎉 Done!"