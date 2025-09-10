#!/bin/bash
# bootstrap.sh - Full EC2 bootstrap: GitHub runner + Kubernetes + all org repos + manifests

set -e

# -----------------------------
# 1️⃣ Setup GitHub Actions runner
# -----------------------------
echo "🚀 Running GitHub Actions runner setup..."
bash /home/ubuntu/scripts/setup.sh

# -----------------------------
# 2️⃣ Setup Kubernetes control plane
# -----------------------------
echo "🚀 Running Kubernetes control plane setup..."
bash /home/ubuntu/scripts/kubeadm.sh

# -----------------------------
# 3️⃣ Clone all repositories in the organization
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
# 4️⃣ Create Kubernetes secret with AWS credentials
# -----------------------------
echo "🔑 Creating Kubernetes secret for AWS credentials..."
kubectl create secret generic bedrock-secrets \
  --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  --from-literal=AWS_DEFAULT_REGION="${AWS_REGION}" \
  --dry-run=client -o yaml | kubectl apply -f -

# -----------------------------
# 5️⃣ Deploy all Kubernetes manifests
# -----------------------------
echo "📦 Deploying all Kubernetes manifests..."
find $CLONE_ROOT -name '*.yaml' -not -path '*/.github/*' \
  -exec kubectl apply -f {} \;

echo "✅ Bootstrap complete: runner ready + Kubernetes + all manifests deployed."
