#!/bin/bash

# Disable swap
sudo swapoff -a

# Stop cluster if it is running
sudo kubeadm reset

# Reguired by some CNI plugins to pass bridged IPv4 traffic to ipltables'chains.
sudo sysctl net.bridge.bridge-nf-call-iptables=1

# Init cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Copy kubeconfig file to $HOME/.kube/config
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown -R floreks $HOME/.kube

# Deploy CNI
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml

# Remove master taints
kubectl taint nodes --all node-role.kubernetes.io/master-

# Deploy Dashboard and Dashboard head
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard-head.yaml

# Make Dashboard admin (for dev)
kubectl create -f https://raw.githubusercontent.com/floreks/k8s-tools/master/example-yaml/dashboard-admin.yaml
kubectl create -f https://raw.githubusercontent.com/floreks/k8s-tools/master/example-yaml/dashboard-admin-head.yaml

# Add some test resources
kubectl create -f https://raw.githubusercontent.com/floreks/k8s-tools/master/example-yaml/all-in-one.yaml

# Start proxy and detach from console
nohup kubectl proxy &
rm nohup.out
