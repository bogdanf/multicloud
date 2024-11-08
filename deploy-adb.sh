#!/bin/bash

# Load configuration from config.json
CONFIG_FILE="config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found."
  exit 1
fi

PROJECT_ID=$(jq -r '.project_id' $CONFIG_FILE)
REGION=$(jq -r '.region' $CONFIG_FILE)
VPC_NAME=$(jq -r '.vpc_name' $CONFIG_FILE)
BASTION_NAME=$(jq -r '.bastion_name' $CONFIG_FILE)
ADMIN_PASSWORD=$(jq -r '.admin_password' $CONFIG_FILE)

# Ask user for database name and display name
read -p "Enter the database name (letters only): " DATABASE_NAME

while [[ $DATABASE_NAME =~ [^a-zA-Z] ]]; do
  echo "Invalid input. Please enter a database name containing only letters."
  read -p "Enter the database name (letters only): " DATABASE_NAME
done

read -p "Enter the database display name (letters only): " DATABASE_DISPLAY_NAME

while [[ $DATABASE_DISPLAY_NAME =~ [^a-zA-Z] ]]; do
  echo "Invalid input. Please enter a database display name containing only letters."
  read -p "Enter the database display name (letters only): " DATABASE_DISPLAY_NAME
done

# Exit immediately if any command fails
set -e

# Function to log messages
log_message() {
  echo "$(date) - INFO - $1"
}

# Log resource IDs to a file
LOG_FILE="resource_ids.log"

# Add SSH key to Compute Engine metadata
log_message "Adding SSH key to Compute Engine metadata..."
ssh-keygen -t rsa -f gcloud-key -C "<USER EMAIL>" || { log_message "Failed to generate SSH key"; exit 1; }
gcloud compute project-info add-metadata --metadata-from-file ssh-keys=<PATH TO>/gcloud-key.pub || { log_message "Failed to add SSH key to metadata"; exit 1; }
log_message "SSH key added successfully."

# Create VPC
log_message "Creating VPC..."
VPC_ID=$(gcloud compute networks create $VPC_NAME --subnet-mode=custom --format='get(id)' || { log_message "Failed to create VPC"; exit 1; })
echo "VPC ID: $VPC_ID" >> $LOG_FILE
log_message "VPC created successfully."

# Create subnets
log_message "Creating subnets..."
PRIVATE_SUBNET_ID=$(gcloud compute networks subnets create private-subnet --network=$VPC_NAME --region=$REGION --range=192.168.5.0/24 --enable-private-ip-google-access --format='get(id)' || { log_message "Failed to create private subnet"; exit 1; })
echo "Private Subnet ID: $PRIVATE_SUBNET_ID" >> $LOG_FILE
PUBLIC_SUBNET_ID=$(gcloud compute networks subnets create public-subnet --network=$VPC_NAME --region=$REGION --range=192.168.4.0/24 --enable-flow-logs --enable-private-ip-google-access --format='get(id)' || { log_message "Failed to create public subnet"; exit 1; })
echo "Public Subnet ID: $PUBLIC_SUBNET_ID" >> $LOG_FILE
log_message "Subnets created successfully."

# Create firewall rules
log_message "Creating firewall rules..."
INGRESS_RULE_ID=$(gcloud compute firewall-rules create allow-common-ports --direction=INGRESS --priority=1000 --network=$VPC_NAME --action=ALLOW --rules=tcp:22,tcp:80,tcp:443,tcp:1522,tcp:3389 --source-ranges=0.0.0.0/0 --description="Allow SSH, HTTP, HTTPS, Autonomous DB, and RDP access" --target-tags=bastion --format='get(id)' || { log_message "Failed to create ingress firewall rule"; exit 1; })
echo "Ingress Firewall Rule ID: $INGRESS_RULE_ID" >> $LOG_FILE
EGRESS_RULE_ID=$(gcloud compute firewall-rules create allow-bastion-egress --direction=EGRESS --priority=1000 --network=$VPC_NAME --action=ALLOW --rules=tcp:22,tcp:80,tcp:443,tcp:1522,tcp:3389 --destination-ranges=0.0.0.0/0 --target-tags=bastion --format='get(id)' || { log_message "Failed to create egress firewall rule"; exit 1; })
echo "Egress Firewall Rule ID: $EGRESS_RULE_ID" >> $LOG_FILE
log_message "Firewall rules created successfully."

# Create bastion host
log_message "Creating bastion host..."
BASTION_HOST_ID=$(gcloud compute instances create bastion-host --zone=$REGION-a --machine-type=e2-micro --subnet=public-subnet --network-tier=PREMIUM --maintenance-policy=MIGRATE --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=20GB --boot-disk-type=pd-balanced --boot-disk-device-name=bastion-host --tags=bastion --format='get(id)' || { log_message "Failed to create bastion host"; exit 1; })
echo "Bastion Host ID: $BASTION_HOST_ID" >> $LOG_FILE
log_message "Bastion host created successfully."

# Create Windows VM
log_message "Creating Windows VM..."
WINDOWS_VM_ID=$(gcloud compute instances create quickstart-winvm --image-family windows-2022 --image-project windows-cloud --machine-type e2-standard-4 --zone $REGION-a --network $VPC_NAME --network-tier=PREMIUM --subnet public-subnet --boot-disk-size 50GB --boot-disk-type pd-ssd --enable-display-device --tags=bastion --format='get(id)' || { log_message "Failed to create Windows VM"; exit 1; })
echo "Windows VM ID: $WINDOWS_VM_ID" >> $LOG_FILE
log_message "Windows VM created successfully."

# Describe Windows VM
log_message "Describing Windows VM..."
gcloud compute instances describe quickstart-winvm --zone=$REGION-a --format='get(name,networkInterfaces[0].accessConfigs[0].natIP)' || { log_message "Failed to describe Windows VM"; exit 1; }
log_message "Windows VM described successfully."

# Retry resetting Windows password with exponential backoff
max_attempts=2
attempt=0
while [ $attempt -lt $max_attempts ]; do
  log_message "Attempting to reset Windows password (attempt ${attempt+1}/${max_attempts})..."
  if gcloud compute reset-windows-password quickstart-winvm --zone=$REGION-a; then
    log_message "Windows password reset successfully."
    break
  else
    log_message "Failed to reset Windows password. Retrying in 30 seconds..."
    sleep 30
    ((attempt++))
  fi
done

if [ $attempt -eq $max_attempts ]; then
  log_message "Failed to reset Windows password after ${max_attempts} attempts."
  exit 1
fi

# Create database
log_message "Creating database..."
DATABASE_ID=$(gcloud oracle-database autonomous-databases create $DATABASE_DISPLAY_NAME --location=$REGION --display-name=$DATABASE_DISPLAY_NAME --database=$DATABASE_NAME --network=$VPC_ID --cidr=192.168.0.0/24 --admin-password=$ADMIN_PASSWORD --properties-compute-count=2 --properties-data-storage-size-gb=500 --properties-db-version=23ai --properties-license-type=LICENSE_INCLUDED --properties-db-workload=OLTP --format='get(id)' || { log_message "Failed to create database"; exit 1; })
echo "Database ID: $DATABASE_ID" >> $LOG_FILE
log_message "Database created successfully."

# Generate wallet
log_message "Generating wallet..."
gcloud oracle-database autonomous-databases generate-wallet $DATABASE_DISPLAY_NAME --location=$REGION --password=Welcome1 || { log_message "Failed to generate wallet"; exit 1; }
log_message "Wallet generated successfully."