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

# -----------------------------
# Persist environment variables system-wide
# -----------------------------
# Overwrite or add values safely: remove existing lines first, then append.
# (This avoids duplicate lines on reruns.)
sudo sed -i '/^GH_PAT=/d' /etc/environment || true
sudo sed -i '/^AWS_ACCESS_KEY_ID=/d' /etc/environment || true
sudo sed -i '/^AWS_SECRET_ACCESS_KEY=/d' /etc/environment || true
sudo sed -i '/^AWS_REGION=/d' /etc/environment || true

cat <<EOF | sudo tee -a /etc/environment >/dev/null
GH_PAT=${GH_PAT}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_REGION}
EOF

# Export for current shell too
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
TOKEN="${GH_PAT}"  # GitHub PAT

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
    git pull origin main || true
    cd $CLONE_ROOT
  fi
done

# -----------------------------
# 3️⃣ Create Kubernetes secret with AWS credentials
# -----------------------------
echo "🔑 Creating Kubernetes secret for AWS credentials..."
su - ubuntu -c 'source /etc/environment; kubectl create secret generic bedrock-secrets \
  --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  --from-literal=AWS_DEFAULT_REGION="${AWS_REGION}" \
  --dry-run=client -o yaml | kubectl apply -f -'

# -----------------------------
# 4️⃣ Deploy all Kubernetes manifests
# -----------------------------
echo "📦 Deploying all Kubernetes manifests..."
su - ubuntu -c 'source /etc/environment; find /home/ubuntu/polyglot-org -name "*.yaml" -not -path "*/.github/*" -exec kubectl apply -f {} \;'

# -----------------------------
# 5️⃣ Setup GitHub Actions runner
# -----------------------------
echo "🚀 Running GitHub Actions runner setup..."
if ! su - ubuntu -c "source /etc/environment && bash /home/ubuntu/scripts/setup.sh"; then
  echo "❌ Runner setup failed"
  exit 1
fi

echo "✅ Bootstrap complete: Kubernetes + projects deployed + runner ready."
