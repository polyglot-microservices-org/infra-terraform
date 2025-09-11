# Terraform Infrastructure with S3 State Management

> **Branch Selection**: Use `main` branch if you don't want S3/DynamoDB state management. Use `s3-dynamodb` branch for remote state storage with locking.

This repository manages AWS infrastructure using Terraform with remote state storage in S3 and DynamoDB for state locking to prevent race conditions in CI/CD environments.

## 🏗️ Architecture

- **S3 Bucket**: Stores Terraform state files remotely
- **DynamoDB Table**: Provides state locking mechanism
- **GitHub Actions**: Automated deployment with state synchronization
- **Ubuntu Runners**: Execute Terraform commands with shared state access

## 📁 Project Structure

```
infra-terraform/
├── terraform/              # Main infrastructure code
│   ├── main.tf             # Provider configuration
│   ├── ec2.tf              # EC2 instance resources
│   ├── variables.tf        # Input variables
│   └── outputs.tf          # Output values
├── terraform-s3/           # Bootstrap S3 & DynamoDB (one-time setup)
│   └── main.tf             # S3 bucket and DynamoDB table
├── .github/workflows/      # CI/CD workflows
│   ├── setup-state.yaml    # Creates S3 & DynamoDB resources
│   └── deploy.yaml         # Deploys infrastructure with state management
└── scripts/                # Bootstrap scripts for EC2
```

## 🚀 Getting Started

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **GitHub Secrets** configured:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
   - `GH_PAT` (GitHub Personal Access Token)

### Step 1: Initial Setup (One-time)

1. **Create S3 Bucket & DynamoDB Table**:
   - Go to GitHub Actions
   - Run `Setup S3 State Backend` workflow manually
   - This creates:
     - S3 bucket: `mitta-terraform-state-bucket`
     - DynamoDB table: `terraform-state-locks`

### Step 2: Deploy Infrastructure

1. **Manual Deployment**:
   - Go to GitHub Actions
   - Run `Deploy Infrastructure` workflow manually

2. **Automatic Deployment**:
   - Push changes to `terraform/` or `scripts/` folders
   - Workflow triggers automatically

## 🔄 State Management Workflow

The deployment process ensures safe state management:

1. **🔒 Acquire Lock**: DynamoDB prevents concurrent modifications
2. **⬇️ Download State**: Pulls latest state from S3
3. **🏗️ Terraform Operations**: Init and apply changes
4. **⬆️ Upload State**: Saves updated state to S3
5. **🔓 Release Lock**: Unlocks for other operations (even on failure)



## 📝 Workflows

### setup-state.yaml
**What happens when you run this workflow:**
1. Checks out repository code
2. Configures AWS CLI with secrets
3. Sets up Terraform 1.6.0
4. Goes to `terraform-s3` folder
5. Runs `terraform init` to initialize
6. Runs `terraform apply -auto-approve` to create:
   - S3 bucket: `mitta-terraform-state-bucket` (with versioning & encryption)
   - DynamoDB table: `terraform-state-locks` (for state locking)

**Trigger**: Manual only (`workflow_dispatch`)
**Usage**: Run once before first deployment

### deploy.yaml
**What happens when you run this workflow:**
1. Checks out repository code
2. Configures AWS CLI with secrets
3. Sets up Terraform 1.6.0
4. **Acquires DynamoDB lock** - Prevents concurrent runs
5. **Downloads current state** from S3 bucket (or shows "No existing state")
6. Runs `terraform init` and `terraform apply` with variables
7. **Uploads updated state** back to S3 bucket
8. **Releases DynamoDB lock** (runs even if previous steps fail)

**Triggers**: Manual or push to `terraform/`/`scripts/` folders

**What the EC2 instance does after deployment:**
- Sets up Kubernetes control plane (kubeadm)
- Clones all repositories from `polyglot-microservices-org`
- Creates Kubernetes secrets with AWS credentials
- Deploys all Kubernetes manifests from cloned repos
- Registers as GitHub Actions self-hosted runner
- Ready to execute GitHub Actions workflows with K8s access
