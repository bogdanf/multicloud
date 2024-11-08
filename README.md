# Deploying Oracle Database on Google Cloud Platform (GCP)

Google Cloud Platform (GCP) provides a comprehensive suite of cloud computing services that enable businesses to build, deploy, and manage applications and workloads in a secure, scalable, and reliable manner. One of the key benefits of using GCP is its ability to support a wide range of databases, including Oracle.

In this blog post, we will walk through the process of deploying an Oracle database on GCP using a Bash script. We will cover the following topics:

- Creating a virtual private cloud (VPC) network
- Creating subnets and firewall rules
- Creating a bastion host and Windows VM
- Deploying an Oracle database
- Generating a wallet for the database

## Prerequisites

Before we begin, make sure you have the following prerequisites:

A GCP account with the necessary permissions to create resources
A Bash shell installed on your system
The gcloud command-line tool installed and configured on your system
Step 1: Create a VPC Network

The first step in deploying an Oracle database on GCP is to create a VPC network. A VPC network is a virtual network that provides a secure and isolated environment for your resources.

## Create VPC
log_message "Creating VPC..."
VPC_ID=$(gcloud compute networks create $VPC_NAME --subnet-mode=custom --format='get(id)' || { log_message "Failed to create VPC"; exit 1; })
echo "VPC ID: $VPC_ID" >> $LOG_FILE
log_message "VPC created successfully."
Step 2: Create Subnets and Firewall Rules

Next, we need to create subnets and firewall rules for our VPC network. Subnets are used to divide a VPC network into smaller segments, while firewall rules control incoming and outgoing traffic to and from our resources.

## Create subnets
log_message "Creating subnets..."
PRIVATE_SUBNET_ID=$(gcloud compute networks subnets create private-subnet --network=$VPC_NAME --region=$REGION --range=192.168.5.0/24 --enable-private-ip-google-access --format='get(id)' || { log_message "Failed to create private subnet"; exit 1; })
echo "Private Subnet ID: $PRIVATE_SUBNET_ID" >> $LOG_FILE
PUBLIC_SUBNET_ID=$(gcloud compute networks subnets create public-subnet --network=$VPC_NAME --region=$REGION --range=192.168.4.0/24 --enable-flow-logs --enable-private-ip-google-access --format='get(id)' || { log_message "Failed to create public subnet"; exit 1; })
echo "Public Subnet ID: $PUBLIC_SUBNET_ID" >> $LOG_FILE
log_message "Subnets created successfully."

## Create firewall rules
log_message "Creating firewall rules..."
INGRESS_RULE_ID=$(gcloud compute firewall-rules create allow-common-ports --direction=INGRESS --priority=1000 --network=$VPC_NAME --action=ALLOW --rules=tcp:22,tcp:80,tcp:443,tcp:1522,tcp:3389 --source-ranges=0.0.0.0/0 --description="Allow SSH, HTTP, HTTPS, Autonomous DB, and RDP access" --target-tags=bastion --format='get(id)' || { log_message "Failed to create ingress firewall rule"; exit 1; })
echo "Ingress Firewall Rule ID: $INGRESS_RULE_ID" >> $LOG_FILE
EGRESS_RULE_ID=$(gcloud compute firewall-rules create allow-bastion-egress --direction=EGRESS --priority=1000 --network=$VPC_NAME --action=ALLOW --rules=tcp:22,tcp:80,tcp:443,tcp:1522,tcp:3389 --destination-ranges=0.0.0.0/0 --target-tags=bastion --format='get(id)' || { log_message "Failed to create egress firewall rule"; exit 1; })
echo "Egress Firewall Rule ID: $EGRESS_RULE_ID" >> $LOG_FILE
log_message "Firewall rules created successfully."
Step 3: Create a Bastion Host and Windows VM

Next, we need to create a bastion host and Windows VM. A bastion host is a secure server that acts as an entry point to our VPC network, while a Windows VM is a virtual machine that runs the Windows operating system.

## Create bastion host
log_message "Creating bastion host..."
BASTION_HOST_ID=$(gcloud compute instances create bastion-host --zone=$REGION-a --machine-type=e2-micro --subnet=public-subnet --network-tier=PREMIUM --maintenance-policy=MIGRATE --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=20GB --boot-disk-type=pd-balanced --boot-disk-device-name=bastion-host --tags=bastion --format='get(id)' || { log_message "Failed to create bastion host"; exit 1; })
echo "Bastion Host ID: $BASTION_HOST_ID" >> $LOG_FILE
log_message "Bastion host created successfully."

## Create Windows VM
log_message "Creating Windows VM..."
WINDOWS_VM_ID=$(gcloud compute instances create quickstart-winvm --image-family windows-2022 --image-project windows-cloud --machine-type e2-standard-4 --zone $REGION-a --network $VPC_NAME --network-tier=PREMIUM --subnet public-subnet --boot-disk-size 50GB --boot-disk-type pd-ssd --enable-display-device --tags=bastion --format='get(id)' || { log_message "Failed to create Windows VM"; exit 1; })
echo "Windows VM ID: $WINDOWS_VM_ID" >> $LOG_FILE
log_message "Windows VM created successfully."
Step 4: Deploy an Oracle Database

Finally, we can deploy an Oracle database on our Windows VM.

## Create database
log_message "Creating database..."
DATABASE_ID=$(gcloud oracle-database autonomous-databases create $DATABASE_DISPLAY_NAME --location=$REGION --display-name=$DATABASE_DISPLAY_NAME --database=$DATABASE_NAME --network=$VPC_ID --cidr=192.168.0.0/24 --admin-password=$ADMIN_PASSWORD --properties-compute-count=2 --properties-data-storage-size-gb=500 --properties-db-version=23ai --properties-license-type=LICENSE_INCLUDED --properties-db-workload=OLTP --format='get(id)' || { log_message "Failed to create database"; exit 1; })
echo "Database ID: $DATABASE_ID" >> $LOG_FILE
log_message "Database created successfully."
Step 5: Generate a Wallet for the Database

Once the database is created, we need to generate a wallet for it.

## Generate wallet
log_message "Generating wallet..."
gcloud oracle-database autonomous-databases generate-wallet $DATABASE_DISPLAY_NAME --location=$REGION --password=Welcome1 || { log_message "Failed to generate wallet"; exit 1; }
log_message "Wallet generated successfully."
That's it! We have successfully deployed an Oracle database on GCP using a Bash script. We hope this tutorial has been helpful in guiding you through the process. Let us know if you have any questions or need further assistance.