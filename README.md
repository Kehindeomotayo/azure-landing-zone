# Azure Enterprise Landing Zone - Secure v2

## GitHub Actions Setup

### Required Secrets

Add these secrets to your GitHub repository:

1. **ARM_CLIENT_ID** - Service Principal Application ID
2. **ARM_CLIENT_SECRET** - Service Principal Secret
3. **ARM_SUBSCRIPTION_ID** - Azure Subscription ID
4. **ARM_TENANT_ID** - Azure Tenant ID
5. **SSH_PUBLIC_KEY** - SSH public key for VMs
6. **SECURITY_CONTACT_EMAIL** - Email for security alerts

### Create Service Principal

```bash
az ad sp create-for-rbac --name "terraform-sp" --role="Contributor" --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"
```

### Workflow Behavior

- **Pull Request**: Runs plan only
- **Push to main**: Runs plan + apply
- **Format check**: Validates Terraform formatting

### Manual Deployment

```bash
terraform init
terraform plan
terraform apply
```