#!/bin/bash
# setup.sh - Install and configure GitHub Actions self-hosted runner on Ubuntu EC2
# Organization-level runner only

set -e

# -----------------------------
# Variables
# -----------------------------
GITHUB_OWNER="polyglot-microservices-org"        # <-- your GitHub org name
RUNNER_TOKEN="${runner_token}"     # injected by Terraform (via templatefile)
RUNNER_DIR="/home/ubuntu/actions-runner"
RUNNER_LABELS="self-hosted,ec2,k8s"

# -----------------------------
# Install dependencies
# -----------------------------
echo "📦 Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl tar jq git

# -----------------------------
# Create runner directory
# -----------------------------
echo "📂 Creating runner directory..."
sudo mkdir -p $RUNNER_DIR
sudo chown ubuntu:ubuntu $RUNNER_DIR
cd $RUNNER_DIR

# -----------------------------
# Download latest runner
# -----------------------------
echo "⬇️ Downloading latest GitHub Actions runner..."
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
curl -L -o actions-runner.tar.gz \
  https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION:1}.tar.gz

# Extract runner
tar xzf ./actions-runner.tar.gz
rm actions-runner.tar.gz

# -----------------------------
# Configure runner (org-level)
# -----------------------------
echo "⚙️ Registering runner at organization level..."
sudo -u ubuntu ./config.sh --url https://github.com/${GITHUB_OWNER} \
  --token ${RUNNER_TOKEN} \
  --name "$(hostname)" \
  --labels ${RUNNER_LABELS} \
  --unattended

# -----------------------------
# Install as a service
# -----------------------------
echo "🔧 Installing runner as a service..."
sudo ./svc.sh install
sudo ./svc.sh start

echo "✅ GitHub Actions self-hosted runner setup complete (org-level)!"
