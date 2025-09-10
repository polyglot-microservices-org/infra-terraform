#!/bin/bash
# Description: This script sets up a Kubernetes control plane node with Weave Net CNI and Metrics Server.

set -e

# ---
# Set the hostname to 'master'
echo "Setting hostname to 'master'..."
sudo hostnamectl set-hostname master

# ---
# Initialize the Kubernetes control plane using kubeadm
echo "Initializing Kubernetes control plane..."
sudo kubeadm init --cri-socket=unix:///var/run/crio/crio.sock

# ---
# Configure kubeconfig for the 'ubuntu' user
echo "Configuring kubeconfig for the 'ubuntu' user..."
sudo mkdir -p /home/ubuntu/.kube
sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# ---
# Install Weave Net CNI (Container Network Interface)
echo "Installing Weave Net CNI..."
sudo -u ubuntu kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# ---
# Wait until the node is in a 'Ready' state
echo "Waiting for the node to become 'Ready'..."
until sudo -u ubuntu kubectl get nodes | grep -q ' Ready '; do
    echo "Node not yet ready. Waiting 5 seconds..."
    sleep 5
done
echo "Node is now 'Ready'."

# ---
# Remove the control-plane taint from the master node
echo "Removing the control-plane taint from the master node..."
sudo -u ubuntu kubectl taint node $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true
echo "Control-plane taint removed."

# ---
# Wait for all kube-system pods to be running
echo "Waiting for all kube-system pods to be 'Running'..."
until sudo -u ubuntu kubectl get pods -n kube-system | grep -Ev 'STATUS|Running|Completed' | wc -l | grep -q '^0$'; do
    echo "Pods not yet ready. Waiting 5 seconds..."
    sleep 5
done
echo "All kube-system pods are 'Running'."

# ---
# Install Metrics Server
echo "Installing Metrics Server..."
sudo -u ubuntu kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# ---
echo "✅ Kubernetes control plane setup is complete with Weave Net CNI and Metrics Server installed."

