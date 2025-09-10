#!/bin/bash
# bootstrap.sh - Full EC2 bootstrap: GitHub runner + Kubernetes + all org repos + manifests

set -e

# Create scripts directory
mkdir -p /home/ubuntu/scripts

# Create setup.sh script
cat > /home/ubuntu/scripts/setup.sh << 'EOF'
${setup_script}
EOF

# Create kubeadm.sh script
cat > /home/ubuntu/scripts/kubeadm.sh << 'EOF'
${kubeadm_script}
EOF

# Make scripts executable
chmod +x /home/ubuntu/scripts/*.sh
chown ubuntu:ubuntu /home/ubuntu/scripts/*.sh

# Export variables for scripts
export GH_PAT="${GH_PAT}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_REGION="${AWS_REGION}"

# -----------------------------
# 1️⃣ Setup Kubernetes control plane
# -----------------------------
echo "🚀 Running Kubernetes control plane setup..."
su - ubuntu -c "bash /home/ubuntu/scripts/kubeadm.sh"

# -----------------------------
# 2️⃣ Clone all repositories in the organization
# -----------------------------
ORG_NAME="polyglot-microservices-org"
CLONE_ROOT="/home/ubuntu/polyglot-org"
TOKEN="${GH_PAT}"  # GitHub PAT passed as env var from Terraform / workflow

mkdir -p $CLONE_ROOT
cd $CLONE_ROOT

echo "📂 Fetching list of repositories in organization..."
REPO_LIST=$(curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/orgs/$ORG_NAME/repos?per_page=100" | jq -r '.[].name')

for repo in $REPO_LIST; do
  if [ ! -d "$CLONE_ROOT/$repo" ]; then
    echo "⬇️ Cloning $repo..."
    git clone https://github.com/$ORG_NAME/$repo.git $CLONE_ROOT/$repo
  else
    echo "🔄 Updating existing $repo..."
    cd $CLONE_ROOT/$repo
    git pull origin main
    cd $CLONE_ROOT
  fi
done

# -----------------------------
# 3️⃣ Create Kubernetes secret with AWS credentials
# -----------------------------
echo "🔑 Creating Kubernetes secret for AWS credentials..."
# Running kubectl as the 'ubuntu' user to use the correct kubeconfig
su - ubuntu -c '
  kubectl create secret generic bedrock-secrets \
    --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    --from-literal=AWS_DEFAULT_REGION="${AWS_REGION}" \
    --dry-run=client -o yaml | kubectl apply -f -
'

# -----------------------------
# 4️⃣ Deploy all Kubernetes manifests
# -----------------------------
echo "📦 Deploying all Kubernetes manifests..."
# Running kubectl as the 'ubuntu' user to use the correct kubeconfig
su - ubuntu -c '
  find $CLONE_ROOT -name "*.yaml" -not -path "*/.github/*" \
    -exec kubectl apply -f {} \;
'

# -----------------------------
# 5️⃣ Setup GitHub Actions runner
# -----------------------------
echo "🚀 Running GitHub Actions runner setup..."
if ! su - ubuntu -c "bash /home/ubuntu/scripts/setup.sh"; then
  echo "❌ Runner setup failed"
  exit 1
fi

echo "✅ Bootstrap complete: Kubernetes + projects deployed + runner ready."