#!/bin/bash

# Do not exit immediately if any command fails
set +e

# # Set variables
# BASTION_NAME=wspluta-bastion-host-name
# ADMIN_PASSWORD=W3lcomeW3lcome
# DATABASE_NAME=wspluta-database-name
# DATABASE_DISPLAY_NAME=wspluta-display-name
# REGION=europe-west2
# VPC_NAME=quickstart-network
# PROJECT_ID=$(gcloud config get-value project)
# NETWORK_PATH=projects/${PROJECT_ID}/global/networks/$VPC_NAME

# Function to log messages
log_message() {
  echo "$(date) - INFO - $1"
}

# Fetch IDs from resource_ids.log
LOG_FILE="resource_ids.log"

if [ ! -f "$LOG_FILE" ]; then
  log_message "Resource IDs log file not found."
  exit 1
fi

VPC_ID=$(grep "VPC ID:" $LOG_FILE | cut -d':' -f2- | tr -d ' ')
PRIVATE_SUBNET_ID=$(grep "Private Subnet ID:" $LOG_FILE | cut -d':' -f2- | tr -d ' ')
PUBLIC_SUBNET_ID=$(grep "Public Subnet ID:" $LOG_FILE | cut -d':' -f2- | tr -d ' ')
INGRESS_RULE_ID=$(grep "Ingress Firewall Rule ID:" $LOG_FILE | cut -d':' -f2- | tr -d ' ')
EGRESS_RULE_ID=$(grep "Egress Firewall Rule ID:" $LOG_FILE | cut -d':' -f2- | tr -d ' ')
BASTION_HOST_ID=$(grep "Bastion Host ID:" $LOG_FILE | cut -d':' -f2- | tr -d ' ')
WINDOWS_VM_ID=$(grep "Windows VM ID:" $LOG_FILE | cut -d':' -f2- | tr -d ' ')

# Delete wallet
log_message "Deleting wallet..."
gcloud oracle-database autonomous-databases delete-wallet $DATABASE_DISPLAY_NAME --location=$REGION || log_message "Failed to delete wallet"
log_message "Wallet deletion attempted."

# Delete database
log_message "Deleting database..."
gcloud oracle-database autonomous-databases delete $DATABASE_DISPLAY_NAME --location=$REGION --async || log_message "Failed to delete database"
log_message "Database deletion initiated."

# Delete Windows VM
log_message "Deleting Windows VM..."
gcloud compute instances delete $WINDOWS_VM_ID --zone=$REGION-a --quiet || log_message "Failed to delete Windows VM"
log_message "Windows VM deletion attempted."

# Delete bastion host
log_message "Deleting bastion host..."
gcloud compute instances delete $BASTION_HOST_ID --zone=$REGION-a --quiet || log_message "Failed to delete bastion host"
log_message "Bastion host deletion attempted."

# Delete firewall rules
log_message "Deleting firewall rules..."
gcloud compute firewall-rules delete $INGRESS_RULE_ID --quiet || log_message "Failed to delete ingress firewall rule"
gcloud compute firewall-rules delete $EGRESS_RULE_ID --quiet || log_message "Failed to delete egress firewall rule"
log_message "Firewall rules deletion attempted."

# Delete subnets
log_message "Deleting subnets..."
gcloud compute networks subnets delete $PRIVATE_SUBNET_ID --region=$REGION --quiet || log_message "Failed to delete private subnet"
gcloud compute networks subnets delete $PUBLIC_SUBNET_ID --region=$REGION --quiet || log_message "Failed to delete public subnet"
log_message "Subnets deletion attempted."

# Delete VPC
log_message "Deleting VPC..."
gcloud compute networks delete $VPC_ID --quiet || log_message "Failed to delete VPC"
log_message "VPC deletion attempted."

# Remove SSH key from Compute Engine metadata
log_message "Removing SSH key from Compute Engine metadata..."
gcloud compute project-info remove-metadata --keys ssh-keys || log_message "Failed to remove SSH key from metadata"
log_message "SSH key removal attempted."