#!/bin/bash
# setup.sh - Install and configure GitHub Actions self-hosted runner on Ubuntu EC2

set -e

# Variables
GITHUB_OWNER="polyglot-microservices-org"
RUNNER_DIR="/home/ubuntu/actions-runner"
RUNNER_LABELS="self-hosted,ec2,k8s"

# Validate GH_PAT
if [ -z "${GH_PAT}" ]; then
  echo "❌ Error: GH_PAT is not set"
  exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl tar jq git

# Create runner directory
echo "📂 Creating runner directory..."
sudo mkdir -p $RUNNER_DIR
sudo chown ubuntu:ubuntu $RUNNER_DIR
cd $RUNNER_DIR

# Download latest runner
echo "⬇️ Downloading latest GitHub Actions runner..."
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
curl -L -o actions-runner.tar.gz \
  https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION:1}.tar.gz

tar xzf ./actions-runner.tar.gz
rm actions-runner.tar.gz

# Generate fresh runner token
echo "🔑 Generating fresh runner token..."
RUNNER_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${GH_PAT}" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/registration-token | jq -r .token)

if [ "$RUNNER_TOKEN" = "null" ] || [ -z "$RUNNER_TOKEN" ]; then
  echo "❌ Error: Failed to generate runner token. Check GH_PAT permissions."
  exit 1
fi

# Configure runner
echo "⚙️ Registering runner at organization level..."
sudo -u ubuntu ./config.sh --url https://github.com/${GITHUB_OWNER} \
  --token ${RUNNER_TOKEN} \
  --name "$(hostname)" \
  --labels ${RUNNER_LABELS} \
  --unattended

# Install and start as service
echo "🔧 Installing runner as a service..."
sudo ./svc.sh install
sudo ./svc.sh start

# Verify service is running
echo "🔍 Verifying runner service..."
sudo systemctl status actions.runner.* --no-pager

echo "✅ GitHub Actions self-hosted runner setup complete!"
