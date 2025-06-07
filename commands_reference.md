# Google Cloud Commands Reference

This document provides a comprehensive reference of all Google Cloud commands used in the Cloud Armor Traffic Blocklisting project.

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Load Balancer Commands](#load-balancer-commands)
3. [VM Management Commands](#vm-management-commands)
4. [Cloud Armor Commands](#cloud-armor-commands)
5. [Logging and Monitoring](#logging-and-monitoring)
6. [Troubleshooting Commands](#troubleshooting-commands)
7. [Cleanup Commands](#cleanup-commands)

## Environment Setup

### Authentication and Project Setup

```bash
# Check current authentication
gcloud auth list

# Login to Google Cloud
gcloud auth login

# Set project ID
gcloud config set project YOUR_PROJECT_ID

# Get current project
gcloud config get-value project

# Set default region and zone
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# View current configuration
gcloud config list
```

### Enable Required APIs

```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Enable Cloud Armor API
gcloud services enable armor.googleapis.com

# Enable Cloud Logging API
gcloud services enable logging.googleapis.com

# List enabled services
gcloud services list --enabled
```

## Load Balancer Commands

### Backend Service Operations

```bash
# Check backend service health
gcloud compute backend-services get-health web-backend --global

# Describe backend service
gcloud compute backend-services describe web-backend --global

# List all backend services
gcloud compute backend-services list

# Update backend service (attach security policy)
gcloud compute backend-services update web-backend \
    --security-policy=POLICY_NAME \
    --global

# Remove security policy from backend service
gcloud compute backend-services update web-backend \
    --no-security-policy \
    --global

# Enable logging on backend service
gcloud compute backend-services update web-backend \
    --enable-logging \
    --logging-sample-rate=1.0 \
    --global
```

### Forwarding Rules

```bash
# Describe forwarding rule
gcloud compute forwarding-rules describe web-rule --global

# Get just the IP address
gcloud compute forwarding-rules describe web-rule --global \
    --format="value(IPAddress)"

# List all forwarding rules
gcloud compute forwarding-rules list

# List global forwarding rules
gcloud compute forwarding-rules list --global
```

### URL Maps and Target Proxies

```bash
# List URL maps
gcloud compute url-maps list

# Describe URL map
gcloud compute url-maps describe web-map --global

# List target HTTP proxies
gcloud compute target-http-proxies list

# Describe target HTTP proxy
gcloud compute target-http-proxies describe web-proxy --global
```

## VM Management Commands

### Instance Operations

```bash
# Create VM instance
gcloud compute instances create VM_NAME \
    --zone=ZONE \
    --machine-type=e2-micro \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard \
    --tags=http-server,https-server

# List all instances
gcloud compute instances list

# Describe specific instance
gcloud compute instances describe VM_NAME --zone=ZONE

# Get instance external IP
gcloud compute instances describe VM_NAME \
    --zone=ZONE \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# Start instance
gcloud compute instances start VM_NAME --zone=ZONE

# Stop instance
gcloud compute instances stop VM_NAME --zone=ZONE

# Delete instance
gcloud compute instances delete VM_NAME --zone=ZONE

# SSH into instance
gcloud compute ssh VM_NAME --zone=ZONE

# Execute command on instance
gcloud compute ssh VM_NAME --zone=ZONE \
    --command="curl -m1 http://example.com"
```

### Instance Groups and Templates

```bash
# List instance groups
gcloud compute instance-groups list

# Describe instance group
gcloud compute instance-groups describe GROUP_NAME --zone=ZONE

# List instances in group
gcloud compute instance-groups list-instances GROUP_NAME --zone=ZONE

# List instance templates
gcloud compute instance-templates list

# Describe instance template
gcloud compute instance-templates describe TEMPLATE_NAME
```

## Cloud Armor Commands

### Security Policy Management

```bash
# Create security policy
gcloud compute security-policies create POLICY_NAME \
    --description="Policy description" \
    --type=CLOUD_ARMOR

# List all security policies
gcloud compute security-policies list

# Describe security policy
gcloud compute security-policies describe POLICY_NAME

# Delete security policy
gcloud compute security-policies delete POLICY_NAME

# Update policy description
gcloud compute security-policies update POLICY_NAME \
    --description="Updated description"
```

### Security Policy Rules

```bash
# Create basic IP blocking rule
gcloud compute security-policies rules create PRIORITY \
    --security-policy=POLICY_NAME \
    --src-ip-ranges="IP_ADDRESS/32" \
    --action=deny-404 \
    --description="Block specific IP"

# Create geographic blocking rule
gcloud compute security-policies rules create PRIORITY \
    --security-policy=POLICY_NAME \
    --expression="origin.region_code == 'CN'" \
    --action=deny-403 \
    --description="Block China traffic"

# Create rate limiting rule
gcloud compute security-policies rules create PRIORITY \
    --security-policy=POLICY_NAME \
    --expression="true" \
    --action=rate-based-ban \
    --rate-limit-threshold-count=100 \
    --rate-limit-threshold-interval-sec=60 \
    --rate-limit-ban-duration-sec=300 \
    --description="Rate limit 100 req/min"

# Create User-Agent blocking rule
gcloud compute security-policies rules create PRIORITY \
    --security-policy=POLICY_NAME \
    --expression="has(request.headers['user-agent']) && request.headers['user-agent'].contains('bot')" \
    --action=deny-403 \
    --description="Block bot traffic"

# List rules in policy
gcloud compute security-policies rules list POLICY_NAME

# Describe specific rule
gcloud compute security-policies rules describe PRIORITY \
    --security-policy=POLICY_NAME

# Update rule
gcloud compute security-policies rules update PRIORITY \
    --security-policy=POLICY_NAME \
    --src-ip-ranges="NEW_IP_ADDRESS/32"

# Delete rule
gcloud compute security-policies rules delete PRIORITY \
    --security-policy=POLICY_NAME
```

### Advanced Rule Examples

```bash
# Block multiple IP ranges
gcloud compute security-policies rules create 1000 \
    --security-policy=POLICY_NAME \
    --src-ip-ranges="192.168.1.0/24,10.0.0.0/8" \
    --action=deny-404

# Allow only specific countries
gcloud compute security-policies rules create 1000 \
    --security-policy=POLICY_NAME \
    --expression="origin.region_code != 'US' && origin.region_code != 'CA'" \
    --action=deny-403

# Block by request size
gcloud compute security-policies rules create 1000 \
    --security-policy=POLICY_NAME \
    --expression="request.headers['content-length'] > '1000000'" \
    --action=deny-413

# Block specific paths
gcloud compute security-policies rules create 1000 \
    --security-policy=POLICY_NAME \
    --expression="request.path.matches('/admin/.*')" \
    --action=deny-404
```

## Logging and Monitoring

### Cloud Logging Commands

```bash
# View Cloud Armor logs
gcloud logging read "resource.type=http_load_balancer AND 
    jsonPayload.enforcedSecurityPolicy.name=POLICY_NAME" \
    --limit=10 \
    --format=json

# View only blocked requests
gcloud logging read "resource.type=http_load_balancer AND 
    jsonPayload.enforcedSecurityPolicy.name=POLICY_NAME AND
    httpRequest.status=404" \
    --limit=10

# View logs from specific time range
gcloud logging read "resource.type=http_load_balancer AND 
    jsonPayload.enforcedSecurityPolicy.name=POLICY_NAME" \
    --since="2024-01-01T00:00:00Z" \
    --until="2024-01-02T00:00:00Z"

# View logs with specific fields
gcloud logging read "resource.type=http_load_balancer AND 
    jsonPayload.enforcedSecurityPolicy.name=POLICY_NAME" \
    --format="value(timestamp,httpRequest.remoteIp,httpRequest.status)"

# Follow logs in real-time
gcloud logging tail "resource.type=http_load_balancer AND 
    jsonPayload.enforcedSecurityPolicy.name=POLICY_NAME"
```

### Monitoring and Metrics

```bash
# List available metrics
gcloud monitoring metrics list --filter="metric.type:compute.googleapis.com"

# Create alerting policy (requires JSON file)
gcloud alpha monitoring policies create --policy-from-file=alert-policy.json

# List alerting policies
gcloud alpha monitoring policies list
```

## Troubleshooting Commands

### Network Diagnostics

```bash
# Test connectivity from VM
gcloud compute ssh VM_NAME --zone=ZONE \
    --command="curl -v -m5 http://LOAD_BALANCER_IP"

# Check firewall rules
gcloud compute firewall-rules list

# Describe specific firewall rule
gcloud compute firewall-rules describe RULE_NAME

# Create firewall rule if needed
gcloud compute firewall-rules create allow-http \
    --allow tcp:80,tcp:8080 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTP traffic"

# Check routes
gcloud compute routes list

# Check health checks
gcloud compute health-checks list
gcloud compute health-checks describe HEALTH_CHECK_NAME
```

### Service Status

```bash
# Check service status
gcloud compute operations list

# Describe specific operation
gcloud compute operations describe OPERATION_ID

# Check quotas
gcloud compute project-info describe \
    --format="value(quotas[].metric,quotas[].limit,quotas[].usage)"

# Check regions and zones
gcloud compute regions list
gcloud compute zones list
```

## Cleanup Commands

### Complete Cleanup Script

```bash
#!/bin/bash

# Remove security policy from backend service
echo "Removing security policy from backend service..."
gcloud compute backend-services update web-backend \
    --no-security-policy \
    --global

# Delete security policy
echo "Deleting security policy..."
gcloud compute security-policies delete blocklist-access-test --quiet

# Delete test VM
echo "Deleting test VM..."
gcloud compute instances delete access-test --zone=us-central1-a --quiet

# Verify cleanup
echo "Verifying cleanup..."
echo "Security policies:"
gcloud compute security-policies list
echo "Test VMs:"
gcloud compute instances list --filter="name:access-test"
echo "Cleanup complete!"
```

### Individual Cleanup Commands

```bash
# Remove policy from backend
gcloud compute backend-services update web-backend \
    --no-security-policy \
    --global

# Delete security policy
gcloud compute security-policies delete POLICY_NAME

# Delete VM
gcloud compute instances delete VM_NAME --zone=ZONE

# Delete firewall rules (if created)
gcloud compute firewall-rules delete RULE_NAME

# Clear gcloud configuration (optional)
gcloud config unset compute/region
gcloud config unset compute/zone
```

## Useful Formatting and Filtering

### Output Formatting

```bash
# JSON format
gcloud compute instances list --format=json

# YAML format
gcloud compute instances list --format=yaml

# Table format with specific columns
gcloud compute instances list \
    --format="table(name,status,zone.basename(),machineType.basename())"

# Get specific values
gcloud compute instances list --format="value(name,zone)"

# Custom formatting
gcloud compute instances list \
    --format="table[box](name:label=VM_NAME,status:label=STATUS)"
```

### Filtering

```bash
# Filter by name
gcloud compute instances list --filter="name:test"

# Filter by zone
gcloud compute instances list --filter="zone:us-central1-a"

# Filter by status
gcloud compute instances list --filter="status:RUNNING"

# Complex filter
gcloud compute instances list \
    --filter="name:test AND status:RUNNING AND zone:us-central1-a"

# Regular expression filter
gcloud compute instances list --filter="name~test-.*"
```

### Sorting

```bash
# Sort by name
gcloud compute instances list --sort-by=name

# Sort by creation timestamp
gcloud compute instances list --sort-by=creationTimestamp

# Reverse sort
gcloud compute instances list --sort-by=~creationTimestamp
```

## Automation and Scripting

### Using gcloud in Scripts

```bash
#!/bin/bash
set -e  # Exit on error

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 succeeded"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

# Example usage
gcloud compute instances create test-vm --zone=us-central1-a
check_success "VM creation"
```

### Batch Operations

```bash
# Create multiple VMs
for i in {1..3}; do
    gcloud compute instances create "test-vm-$i" \
        --zone=us-central1-a \
        --machine-type=e2-micro &
done
wait

# Delete multiple resources
gcloud compute instances list --format="value(name)" | \
    grep "test-" | \
    xargs -I {} gcloud compute instances delete {} --zone=us-central1-a --quiet
```

This reference covers all the essential gcloud commands you'll need for managing Google Cloud Armor and Application Load Balancers. Keep this handy for quick reference during implementation and troubleshooting.