#!/bin/bash

# AWS Resource Lister - Lists all major resources in a region
# Usage: ./list_all_resources.sh [region]

set -e

# Default region
REGION="${1:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print subsection headers
print_subheader() {
    echo -e "\n${YELLOW}--- $1 ---${NC}"
}

# Function to handle errors gracefully
safe_aws_call() {
    local service="$1"
    local command="$2"
    shift 2
    
    echo -e "${GREEN}Checking $service...${NC}"
    if ! eval "$command" 2>/dev/null; then
        echo -e "${RED}  ❌ Error accessing $service or no permissions${NC}"
    fi
}

echo -e "${GREEN}🔍 AWS Resource Inventory for Region: ${YELLOW}$REGION${NC}"
echo -e "${GREEN}📅 Generated: $(date)${NC}"

# Test AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}❌ AWS credentials not configured or invalid${NC}"
    echo "Run: aws configure"
    exit 1
fi

# EC2 Resources
print_header "💻 EC2 RESOURCES"

safe_aws_call "EC2 Instances" '
aws ec2 describe-instances \
    --region $REGION \
    --query "Reservations[].Instances[].[InstanceId,Tags[?Key==\`Name\`].Value|[0],State.Name,InstanceType,PublicIpAddress,PrivateIpAddress]" \
    --output table
'

safe_aws_call "Security Groups" '
aws ec2 describe-security-groups \
    --region $REGION \
    --query "SecurityGroups[].[GroupId,GroupName,Description,VpcId]" \
    --output table
'

safe_aws_call "Key Pairs" '
aws ec2 describe-key-pairs \
    --region $REGION \
    --query "KeyPairs[].[KeyName,KeyPairId,KeyType]" \
    --output table
'

safe_aws_call "Elastic IPs" '
aws ec2 describe-addresses \
    --region $REGION \
    --query "Addresses[].[PublicIp,AllocationId,InstanceId,AssociationId]" \
    --output table
'

safe_aws_call "Load Balancers (Classic)" '
aws elb describe-load-balancers \
    --region $REGION \
    --query "LoadBalancerDescriptions[].[LoadBalancerName,DNSName,Scheme,VPCId]" \
    --output table
'

safe_aws_call "Application Load Balancers" '
aws elbv2 describe-load-balancers \
    --region $REGION \
    --query "LoadBalancers[].[LoadBalancerName,DNSName,Type,Scheme,VpcId]" \
    --output table
'

# VPC Resources
print_header "🌐 VPC RESOURCES"

safe_aws_call "VPCs" '
aws ec2 describe-vpcs \
    --region $REGION \
    --query "Vpcs[].[VpcId,CidrBlock,State,IsDefault,Tags[?Key==\`Name\`].Value|[0]]" \
    --output table
'

safe_aws_call "Subnets" '
aws ec2 describe-subnets \
    --region $REGION \
    --query "Subnets[].[SubnetId,VpcId,CidrBlock,AvailabilityZone,State,Tags[?Key==\`Name\`].Value|[0]]" \
    --output table
'

safe_aws_call "Internet Gateways" '
aws ec2 describe-internet-gateways \
    --region $REGION \
    --query "InternetGateways[].[InternetGatewayId,State,Attachments[0].VpcId,Tags[?Key==\`Name\`].Value|[0]]" \
    --output table
'

safe_aws_call "Route Tables" '
aws ec2 describe-route-tables \
    --region $REGION \
    --query "RouteTables[].[RouteTableId,VpcId,length(Associations),Tags[?Key==\`Name\`].Value|[0]]" \
    --output table
'

safe_aws_call "NAT Gateways" '
aws ec2 describe-nat-gateways \
    --region $REGION \
    --query "NatGateways[].[NatGatewayId,VpcId,SubnetId,State,NatGatewayAddresses[0].PublicIp]" \
    --output table
'

# Storage Resources
print_header "💾 STORAGE RESOURCES"

safe_aws_call "EBS Volumes" '
aws ec2 describe-volumes \
    --region $REGION \
    --query "Volumes[].[VolumeId,Size,VolumeType,State,Attachments[0].InstanceId,Tags[?Key==\`Name\`].Value|[0]]" \
    --output table
'

safe_aws_call "EBS Snapshots (Your Account)" '
aws ec2 describe-snapshots \
    --region $REGION \
    --owner-ids self \
    --query "Snapshots[].[SnapshotId,VolumeId,State,Progress,StartTime,Description]" \
    --output table
'

safe_aws_call "S3 Buckets" '
aws s3api list-buckets \
    --query "Buckets[].[Name,CreationDate]" \
    --output table
'

# Database Resources
print_header "🗄️ DATABASE RESOURCES"

safe_aws_call "RDS Instances" '
aws rds describe-db-instances \
    --region $REGION \
    --query "DBInstances[].[DBInstanceIdentifier,DBInstanceClass,Engine,EngineVersion,DBInstanceStatus,Endpoint.Address]" \
    --output table
'

safe_aws_call "DynamoDB Tables" '
aws dynamodb list-tables \
    --region $REGION \
    --query "TableNames" \
    --output table
'

# IAM Resources (Global)
print_header "🔐 IAM RESOURCES (Global)"

safe_aws_call "IAM Users" '
aws iam list-users \
    --query "Users[].[UserName,CreateDate,PasswordLastUsed]" \
    --output table
'

safe_aws_call "IAM Roles" '
aws iam list-roles \
    --query "Roles[].[RoleName,CreateDate,Description]" \
    --output table
'

safe_aws_call "IAM Policies (Customer Managed)" '
aws iam list-policies \
    --scope Local \
    --query "Policies[].[PolicyName,Arn,CreateDate,IsAttachable]" \
    --output table
'

# Lambda Functions
print_header "⚡ LAMBDA FUNCTIONS"

safe_aws_call "Lambda Functions" '
aws lambda list-functions \
    --region $REGION \
    --query "Functions[].[FunctionName,Runtime,Handler,LastModified,CodeSize]" \
    --output table
'

# CloudFormation Stacks
print_header "📚 CLOUDFORMATION STACKS"

safe_aws_call "CloudFormation Stacks" '
aws cloudformation list-stacks \
    --region $REGION \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query "StackSummaries[].[StackName,StackStatus,CreationTime,LastUpdatedTime]" \
    --output table
'

# Cost Information (if available)
print_header "💰 COST INFORMATION"

safe_aws_call "Current Month Costs" '
aws ce get-cost-and-usage \
    --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics "BlendedCost" \
    --query "ResultsByTime[0].Total.BlendedCost.[Amount,Unit]" \
    --output table
'

# Resource Count Summary
print_header "📊 RESOURCE SUMMARY"

echo -e "${GREEN}Generating resource counts...${NC}"

# Count resources
INSTANCES=$(aws ec2 describe-instances --region $REGION --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "0")
SECURITY_GROUPS=$(aws ec2 describe-security-groups --region $REGION --query 'length(SecurityGroups[])' --output text 2>/dev/null || echo "0")
KEY_PAIRS=$(aws ec2 describe-key-pairs --region $REGION --query 'length(KeyPairs[])' --output text 2>/dev/null || echo "0")
VPCS=$(aws ec2 describe-vpcs --region $REGION --query 'length(Vpcs[])' --output text 2>/dev/null || echo "0")
VOLUMES=$(aws ec2 describe-volumes --region $REGION --query 'length(Volumes[])' --output text 2>/dev/null || echo "0")
BUCKETS=$(aws s3api list-buckets --query 'length(Buckets[])' --output text 2>/dev/null || echo "0")

cat << EOF

📋 Resource Count for Region: $REGION
=====================================
🖥️  EC2 Instances:     $INSTANCES
🛡️  Security Groups:   $SECURITY_GROUPS  
🔑 Key Pairs:         $KEY_PAIRS
🌐 VPCs:              $VPCS
💾 EBS Volumes:       $VOLUMES
🪣 S3 Buckets:        $BUCKETS (Global)

📍 Region: $REGION
⏰ Generated: $(date)
👤 Account: $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")

EOF

echo -e "${GREEN}✅ Resource inventory complete!${NC}"
echo -e "${YELLOW}💡 Tip: Use './remove_ec2_instances.sh' to clean up unused EC2 resources${NC}"