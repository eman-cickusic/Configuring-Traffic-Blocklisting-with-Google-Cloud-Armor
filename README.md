# Configuring Traffic Blocklisting with Google Cloud Armor

A comprehensive guide to configuring traffic blocklisting with Google Cloud Armor for Application Load Balancers.

## Video

https://youtu.be/T8yujOXxWs4

## 📋 Overview

This project demonstrates how to implement and configure Google Cloud Armor IP blocklists/allowlists to restrict access to Application Load Balancers at the edge of Google's network. The implementation prevents malicious traffic from consuming resources or entering your VPC networks by blocking requests at Google's points of presence (POP) worldwide.

## 🎯 Objectives

By following this guide, you will learn to:

- ✅ Verify Application Load Balancer deployment
- ✅ Create test VMs for load balancer access validation
- ✅ Configure Google Cloud Armor security policies
- ✅ Implement IP blocklisting for traffic restriction
- ✅ Monitor and analyze Cloud Armor logs

## 🏗️ Architecture

```
Internet → Google Cloud Armor → Application Load Balancer → Backend Services
    ↓              ↓                        ↓                    ↓
  Users      Security Policy         Global LB            VM Instances
             (Allow/Deny)           (Multi-region)        (Multiple zones)
```

## 🛠️ Prerequisites

- Google Cloud Platform account with billing enabled
- Basic knowledge of Google Cloud Console
- Familiarity with command-line interface
- Understanding of load balancing concepts

## 📚 Project Structure

```
.
├── README.md
├── docs/
│   ├── setup-guide.md
│   ├── security-policies.md
│   └── troubleshooting.md
├── scripts/
│   ├── setup-load-balancer.sh
│   ├── create-test-vm.sh
│   └── configure-armor.sh
├── configs/
│   ├── armor-policy.yaml
│   └── backend-config.yaml
└── examples/
    ├── curl-commands.md
    └── gcloud-commands.md
```

## 🚀 Quick Start

### Step 1: Environment Setup

1. **Activate Cloud Shell**
   ```bash
   # Open Google Cloud Console and activate Cloud Shell
   # Or use gcloud CLI locally
   ```

2. **Set Project Variables**
   ```bash
   export PROJECT_ID=$(gcloud config get-value project)
   export REGION="us-central1"
   export ZONE="us-central1-a"
   ```

### Step 2: Verify Load Balancer Deployment

1. **Check Backend Health**
   ```bash
   gcloud compute backend-services get-health web-backend --global
   ```
   
   *Wait until all instances show as HEALTHY*

2. **Get Load Balancer IP**
   ```bash
   gcloud compute forwarding-rules describe web-rule --global
   ```
   
   *Copy the IPAddress value for later use*

3. **Test Load Balancer Access**
   ```bash
   # Replace {IP_ADDRESS} with your actual load balancer IP
   curl -m1 {IP_ADDRESS}
   
   # Continuous testing
   while true; do curl -m1 {IP_ADDRESS}; sleep 1; done
   ```

### Step 3: Create Test VM

1. **Create VM Instance**
   ```bash
   gcloud compute instances create access-test \
     --zone=$ZONE \
     --machine-type=e2-micro \
     --image-family=debian-11 \
     --image-project=debian-cloud
   ```

2. **Connect via SSH**
   ```bash
   gcloud compute ssh access-test --zone=$ZONE
   ```

3. **Test from VM**
   ```bash
   curl -m1 {IP_ADDRESS}
   ```

### Step 4: Configure Google Cloud Armor

1. **Create Security Policy**
   ```bash
   gcloud compute security-policies create blocklist-access-test \
     --description="Policy to blocklist access-test VM"
   ```

2. **Get VM External IP**
   ```bash
   VM_IP=$(gcloud compute instances describe access-test \
     --zone=$ZONE \
     --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
   ```

3. **Add Blocklist Rule**
   ```bash
   gcloud compute security-policies rules create 1000 \
     --security-policy=blocklist-access-test \
     --src-ip-ranges=$VM_IP \
     --action=deny-404
   ```

4. **Attach Policy to Backend Service**
   ```bash
   gcloud compute backend-services update web-backend \
     --security-policy=blocklist-access-test \
     --global
   ```

### Step 5: Verify Security Policy

1. **Test from Blocked VM**
   ```bash
   # SSH into access-test VM
   curl -m1 {IP_ADDRESS}
   # Should return: 404 Not Found
   ```

2. **Test from Browser**
   - Visit `http://{IP_ADDRESS}` in your browser
   - Should still work (only VM IP is blocked)

## 📊 Monitoring and Logs

### View Cloud Armor Logs

1. **Navigate to Cloud Armor Policies**
   - Go to: Network Security → Cloud Armor policies
   - Click on `blocklist-access-test`
   - Click "Logs" tab

2. **Analyze Log Entries**
   ```bash
   # View logs via gcloud
   gcloud logging read "resource.type=http_load_balancer AND 
     jsonPayload.enforcedSecurityPolicy.name=blocklist-access-test" \
     --limit=10 --format=json
   ```

### Key Metrics to Monitor

- **Request Volume**: Track blocked vs allowed requests
- **Geographic Distribution**: Identify attack sources
- **Response Codes**: Monitor 404 (blocked) responses
- **Policy Effectiveness**: Measure threat mitigation

## 🔧 Advanced Configuration

### Custom Security Rules

```yaml
# Example: Rate limiting rule
gcloud compute security-policies rules create 2000 \
  --security-policy=blocklist-access-test \
  --expression="origin.region_code == 'US'" \
  --action=rate-based-ban \
  --rate-limit-threshold-count=100 \
  --rate-limit-threshold-interval-sec=60
```

### Geographic Restrictions

```bash
# Block specific countries
gcloud compute security-policies rules create 3000 \
  --security-policy=blocklist-access-test \
  --expression="origin.region_code == 'CN' || origin.region_code == 'RU'" \
  --action=deny-403
```

## 🧪 Testing Scenarios

### Load Testing

```bash
# Stress test with multiple requests
for i in {1..100}; do
  curl -s -o /dev/null -w "%{http_code}\n" {IP_ADDRESS} &
done
wait
```

### Security Validation

```bash
# Test different IP ranges
# Test with VPN from different regions
# Verify policy inheritance
```

## 🔍 Troubleshooting

### Common Issues

1. **Policy Not Taking Effect**
   - Wait 2-3 minutes for propagation
   - Verify policy attachment to backend service
   - Check rule priority order

2. **Load Balancer 404/502 Errors**
   - Verify backend health status
   - Check firewall rules
   - Confirm instance group configuration

3. **Logs Not Appearing**
   - Enable logging on the load balancer
   - Check IAM permissions for Cloud Logging
   - Verify log retention settings

### Debug Commands

```bash
# Check backend service configuration
gcloud compute backend-services describe web-backend --global

# Verify security policy rules
gcloud compute security-policies describe blocklist-access-test

# Check VM network configuration
gcloud compute instances describe access-test --zone=$ZONE
```

## 📈 Performance Considerations

- **Edge Processing**: Blocking happens at Google's edge locations
- **Minimal Latency**: No additional latency for allowed traffic
- **Scalability**: Handles high-volume attacks automatically
- **Cost Efficiency**: Pay only for policy evaluations

## 🔒 Security Best Practices

1. **Principle of Least Privilege**: Start with deny-all, allow specific IPs
2. **Regular Auditing**: Review and update policies periodically
3. **Monitoring**: Set up alerts for blocked traffic spikes
4. **Documentation**: Maintain clear policy documentation
5. **Testing**: Regularly test policy effectiveness

## 📚 Additional Resources

- [Google Cloud Armor Documentation](https://cloud.google.com/armor/docs)
- [Application Load Balancer Guide](https://cloud.google.com/load-balancing/docs/https)
- [VPC Flow Logs](https://cloud.google.com/vpc/docs/flow-logs)
- [Cloud Logging](https://cloud.google.com/logging/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This project was created as part of Google Cloud Platform learning and can be used for educational and production purposes. Always follow your organization's security policies and compliance requirements.
