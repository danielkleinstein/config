#!/bin/bash

REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text | tr '\t' '\n')

# Manipulate the list to make us-east-1 the top choice
PRIORITY_REGION="us-east-1"
ORDERED_REGIONS=$(echo -e "$PRIORITY_REGION\n$(echo "$REGIONS" | grep -v "$PRIORITY_REGION")")
SELECTED_REGION=$(echo "$ORDERED_REGIONS" | fzf --header="Select an AWS region:")
# Default to us-east-1
REGION=${SELECTED_REGION:-us-east-1}

AMAZON_LINUX_AMI=$(aws ec2 describe-images --region $REGION --owners amazon \
                   --filters "Name=description,Values=Amazon Linux 2023 AMI 2023* x86_64 HVM kernel-6.1" \
                   --query 'sort_by(Images, &CreationDate) | [-1].ImageId' \
                   --output text)

UBUNTU_AMI=$(aws ec2 describe-images --region $REGION --owners amazon \
            --filters "Name=description,Values=*Ubuntu*22.04*LTS*" \
            --query 'Images | [? !contains(Description, `UNSUPPORTED`) && !contains(Description, `Pro`) && !contains(Description, `Minimal`)] | sort_by(@, &CreationDate) | [-1].ImageId' \
            --output text)

CHOSEN_AMI=$(echo -e "Amazon Linux AMI: $AMAZON_LINUX_AMI\nUbuntu AMI: $UBUNTU_AMI" | fzf | awk '{print $NF}')

INSTANCE_DETAILS=$(aws ec2 describe-instance-types --region $REGION \
         --query "InstanceTypes[?starts_with(InstanceType, 'c') || starts_with(InstanceType, 'm')].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]" \
         --output text | awk '{print $1 " - " $2 " vCPUs, " $3/1024 " GiB RAM"}' | sort)

CHOSEN_INSTANCE=$(echo "$INSTANCE_DETAILS" | fzf | awk '{print $1}')

echo "Starting EC2 Instance with AMI $CHOSEN_AMI and instance type $CHOSEN_INSTANCE..."

KEY_NAME="my-key-$(date +%Y%m%d%H%M%S)"
aws ec2 create-key-pair --region $REGION --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem

chmod 400 $KEY_NAME.pem

INSTANCE_TYPE=$(echo $CHOSEN_INSTANCE | awk '{print $1}')
INSTANCE_ID=$(aws ec2 run-instances --region $REGION --image-id $CHOSEN_AMI --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --query 'Instances[0].InstanceId' --output text)

echo "Waiting for the instance to start..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

INSTANCE_IP=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "You can connect to the instance using:"
echo "ssh -i $KEY_NAME.pem ec2-user@$INSTANCE_IP"
