#!/bin/bash

local ETCD_IP="192.168.30.230"
local ETCD_PORT="2379"
local BIND_ADDRESS="192.168.30.230"
local CERT_DIR="/var/run/kubernetes"
local SUPER_USER_NAME="kube-admin"

local KUBELET_CFG_PATH="/home/floreks/.kube"
local KUBELET_IP="192.168.30.230"

export API_SERVER_ARGS="--etcd-servers=http://${ETCD_IP}:${ETCD_PORT}" \
  "--service-cluster-ip-range=10.0.0.1/24" \
  "--bind-address=${BIND_ADDRESS}" \
  "--client-ca-file=${CERT_DIR}/ca.crt" \
  "--tls-cert-file=${CERT_DIR}/apiserver.crt" \
  "--tls-private-key-file=${CERT_DIR}/apiserver.key" \
  "--secure-port=443" \
  "--allow-privileged=true" \
  "--admission-control=NamespaceLifecycle,LimitRanger,ResourceQuota,ServiceAccount" \
  "--runtime-config=rbac.authorization.k8s.io/v1alpha1,extensions/v1beta1/networkpolicies=true" \
  "--authorization-mode=RBAC" \
  "--authorization-rbac-super-user=${SUPER_USER_NAME}" \
  "--requestheader-client-ca-file=${CERT_DIR}/ca.crt" \
  "--requestheader-username-headers='X-Remote-User'" \
  "--kubelet-certificate-authority=${CERT_DIR}/ca.crt" \
  "--kubelet-https=true"

export KUBELET_ARGS="--kubeconfig=${KUBELET_CFG_PATH}/kubelet.cfg" \
  "--require-kubeconfig" \
  "--cluster-dns=10.0.0.10" \
  "--cluster-domain=cluster.local" \
  "--allow-privileged=true" \
  "--cert-dir=${CERT_DIR}" \
  "--hostname-override=${KUBELET_IP}"

# Different certificates and configs should be used for other components but for dev we can use same as for kubelet on the master
export KUBE_PROXY_ARGS="--kubeconfig=${KUBELET_CFG_PATH}/kubelet.cfg"
export KUBE_CTRL_MGR_ARGS="--kubeconfig=${KUBELET_CFG_PATH}/kubelet.cfg" \
  "--cluster-signing-cert-file=${CERT_DIR}/ca.crt" \
  "--cluster-signing-key-file=${CERT_DIR}/ca.key" \
  "--service-account-private-key-file=${CERT_DIR}/apiserver.key" \
  "--root-ca-file=${CERT_DIR}/ca.crt"

export KUBE_SCHEDULER_ARGS=${KUBE_PROXY_ARGS}
