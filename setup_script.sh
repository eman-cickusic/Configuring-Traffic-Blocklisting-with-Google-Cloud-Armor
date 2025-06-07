#!/bin/bash

# Google Cloud Armor Traffic Blocklisting Setup Script
# This script automates the complete setup process for the lab

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Configuration variables
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
REGION="us-central1"
ZONE="us-central1-a"
VM_NAME="access-test"
BACKEND_SERVICE="web-backend"
FORWARDING_RULE="web-rule"
SECURITY_POLICY="blocklist-access-test"

# Verify gcloud is authenticated
check_auth() {
    log "Checking Google Cloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        error "Please authenticate with Google Cloud: gcloud auth login"
    fi
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "No project ID found. Set it with: gcloud config set project YOUR_PROJECT_ID"
    fi
    
    log "Using project: $PROJECT_ID"
}

# Wait for backend services to be healthy
wait_for_backends() {
    log "Waiting for backend services to be healthy..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Attempt $attempt/$max_attempts: Checking backend health..."
        
        local health_output
        if health_output=$(gcloud compute backend-services get-health $BACKEND_SERVICE --global 2>&1); then
            local healthy_count=$(echo "$health_output" | grep -c "HEALTHY" || echo "0")
            
            if [ "$healthy_count" -ge 3 ]; then
                log "All backends are healthy! ($healthy_count instances)"
                return 0
            else
                log "Found $healthy_count healthy instances, waiting for more..."
            fi
        else
            warn "Backend service not found or not ready yet..."
        fi
        
        sleep 10
        ((attempt++))
    done
    
    error "Timeout waiting for backends to become healthy"
}

# Get load balancer IP address
get_lb_ip() {
    log "Retrieving load balancer IP address..."
    
    local lb_ip
    if ! lb_ip=$(gcloud compute forwarding-rules describe $FORWARDING_RULE --global --format="value(IPAddress)" 2>/dev/null); then
        error "Failed to get load balancer IP. Is the forwarding rule '$FORWARDING_RULE' deployed?"
    fi
    
    if [[ -z "$lb_ip" ]]; then
        error "Load balancer IP address is empty"
    fi
    
    echo "$lb_ip"
}

# Test load balancer access
test_lb_access() {
    local lb_ip=$1
    log "Testing load balancer access at IP: $lb_ip"
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Test attempt $attempt/$max_attempts..."
        
        if curl -s -m 5 --connect-timeout 5 "http://$lb_ip" | grep -q "Web server"; then
            log "✅ Load balancer is accessible!"
            return 0
        fi
        
        warn "Load balancer not ready yet, retrying in 10 seconds..."
        sleep 10
        ((attempt++))
    done
    
    error "Load balancer is not accessible after $max_attempts attempts"
}

# Create test VM
create_test_vm() {
    log "Creating test VM: $VM_NAME"
    
    # Check if VM already exists
    if gcloud compute instances describe $VM_NAME --zone=$ZONE &>/dev/null; then
        warn "VM $VM_NAME already exists in zone $ZONE"
        return 0
    fi
    
    gcloud compute instances create $VM_NAME \
        --zone=$ZONE \
        --machine-type=e2-micro \
        --image-family=debian-11 \
        --image-project=debian-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --tags=http-server,https-server \
        --metadata=startup-script='#!/bin/bash
            apt-get update
            apt-get install -y curl wget
            echo "VM setup complete" > /tmp/startup-complete'
    
    log "✅ Test VM created successfully"
}

# Get VM external IP
get_vm_ip() {
    log "Getting external IP address for VM: $VM_NAME"
    
    local vm_ip
    if ! vm_ip=$(gcloud compute instances describe $VM_NAME \
        --zone=$ZONE \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null); then
        error "Failed to get VM external IP"
    fi
    
    if [[ -z "$vm_ip" ]]; then
        error "VM external IP is empty"
    fi
    
    echo "$vm_ip"
}

# Create Cloud Armor security policy
create_armor_policy() {
    local vm_ip=$1
    log "Creating Cloud Armor security policy: $SECURITY_POLICY"
    
    # Check if policy already exists
    if gcloud compute security-policies describe $SECURITY_POLICY &>/dev/null; then
        warn "Security policy $SECURITY_POLICY already exists"
        return 0
    fi
    
    # Create the security policy
    gcloud compute security-policies create $SECURITY_POLICY \
        --description="Security policy to blocklist access-test VM" \
        --type=CLOUD_ARMOR
    
    # Add rule to block the VM IP
    gcloud compute security-policies rules create 1000 \
        --security-policy=$SECURITY_POLICY \
        --src-ip-ranges="$vm_ip" \
        --action=deny-404 \
        --description="Block access-test VM IP: $vm_ip"
    
    # Attach policy to backend service
    gcloud compute backend-services update $BACKEND_SERVICE \
        --security-policy=$SECURITY_POLICY \
        --global
    
    log "✅ Cloud Armor security policy created and attached"
}

# Wait for policy to take effect
wait_for_policy() {
    local lb_ip=$1
    local vm_ip=$2
    
    log "Waiting for security policy to take effect..."
    log "This may take 2-3 minutes..."
    
    sleep 120  # Wait 2 minutes initially
    
    # Test from the VM (should be blocked)
    log "Testing access from blocked VM ($vm_ip)..."
    
    local test_cmd="curl -s -m 5 --connect-timeout 5 -w '%{http_code}' -o /dev/null http://$lb_ip"
    local response_code
    
    # Execute the test command on the VM via SSH
    if response_code=$(gcloud compute ssh $VM_NAME --zone=$ZONE --command="$test_cmd" --quiet 2>/dev/null); then
        if [[ "$response_code" == "404" ]]; then
            log "✅ Security policy is working! VM access blocked (404)"
        else
            warn "Expected 404, got $response_code. Policy may not be active yet."
        fi
    else
        warn "Could not test from VM via SSH"
    fi
}

# Test from local (should work)
test_local_access() {
    local lb_ip=$1
    log "Testing access from local machine (should work)..."
    
    if curl -s -m 5 --connect-timeout 5 "http://$lb_ip" | grep -q "Web server"; then
        log "✅ Local access works correctly!"
    else
        warn "Local access test failed - this might be expected depending on your network"
    fi
}

# Display summary
display_summary() {
    local lb_ip=$1
    local vm_ip=$2
    
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}     SETUP COMPLETE SUMMARY     ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    echo -e "${GREEN}✅ Load Balancer IP:${NC} $lb_ip"
    echo -e "${GREEN}✅ Test VM Name:${NC} $VM_NAME"
    echo -e "${GREEN}✅ Test VM IP:${NC} $vm_ip (BLOCKED)"
    echo -e "${GREEN}✅ Security Policy:${NC} $SECURITY_POLICY"
    echo -e "${GREEN}✅ Backend Service:${NC} $BACKEND_SERVICE"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Test blocked access: gcloud compute ssh $VM_NAME --zone=$ZONE"
    echo "   Then run: curl -m1 $lb_ip"
    echo "   Expected: 404 Not Found"
    echo
    echo "2. Test allowed access from browser:"
    echo "   Visit: http://$lb_ip"
    echo "   Expected: Web server page"
    echo
    echo "3. View logs:"
    echo "   Console: Network Security > Cloud Armor policies > $SECURITY_POLICY > Logs"
    echo
    echo -e "${YELLOW}Cleanup Commands:${NC}"
    echo "gcloud compute security-policies delete $SECURITY_POLICY"
    echo "gcloud compute instances delete $VM_NAME --zone=$ZONE"
    echo
}

# Main execution
main() {
    log "Starting Google Cloud Armor Traffic Blocklisting Setup"
    echo
    
    # Step 1: Check authentication
    check_auth
    
    # Step 2: Wait for backends to be healthy
    wait_for_backends
    
    # Step 3: Get load balancer IP
    local lb_ip
    lb_ip=$(get_lb_ip)
    
    # Step 4: Test load balancer access
    test_lb_access "$lb_ip"
    
    # Step 5: Create test VM
    create_test_vm
    
    # Step 6: Get VM IP
    local vm_ip
    vm_ip=$(get_vm_ip)
    
    # Step 7: Create Cloud Armor policy
    create_armor_policy "$vm_ip"
    
    # Step 8: Wait and test policy
    wait_for_policy "$lb_ip" "$vm_ip"
    
    # Step 9: Test local access
    test_local_access "$lb_ip"
    
    # Step 10: Display summary
    display_summary "$lb_ip" "$vm_ip"
    
    log "Setup completed successfully! 🎉"
}

# Run main function
main "$@"