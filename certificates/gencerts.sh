#!/bin/bash

# Config files
OPENSSL_BASE_SERVER_CNF="openssl-base-apiserver.cnf"
OPENSSL_BASE_KUBELET_CNF="openssl-base-kubelet.cnf"

# Master and service ip
K8S_MASTER_IP="192.168.30.230"
K8S_SERVICE_IP="10.0.0.1"

# Super user name
ADMIN_USERNAME="kube-admin"

OUTPUT_DIR="generated"
COPY_TO="/var/run/kubernetes"

CLUSTER_DOMAIN="cluster.local"

# By default create csr if it already exists then iterate with CAserial
CA_SERIAL_PARAM="-CAcreateserial"

function generate::ssl::apiserver::conf {
  IP_LIST=$1
  DNS_LIST=$2
  CNF_FILENAME="${OUTPUT_DIR}/${3}.cnf"

  cp $OPENSSL_BASE_SERVER_CNF "${CNF_FILENAME}"

  local IFS=,
  local LIST=($IP_LIST)
  local COUNT=1
  for IP in "${LIST[@]}"; do
    echo "IP.${COUNT} = ${IP}" >> "${CNF_FILENAME}"
    (( COUNT++ ))
  done

  IFS=,
  LIST=($DNS_LIST)
  COUNT=5
  for DNS in "${LIST[@]}"; do
    echo "DNS.${COUNT} = ${DNS}" >> "${CNF_FILENAME}"
    (( COUNT++ ))
  done
}

function generate::ssl::kubelet::conf {
  IP_LIST=$1
  CNF_FILENAME="${OUTPUT_DIR}/${2}.cnf"

  cp $OPENSSL_BASE_KUBELET_CNF "${CNF_FILENAME}"

  local IFS=,
  local LIST=($IP_LIST)
  local COUNT=1
  for IP in "${LIST[@]}"; do
    echo "IP.${COUNT} = ${IP}" >> "${CNF_FILENAME}"
    (( COUNT++ ))
  done
}

function generate::ca::cert {
  openssl genrsa -out "${OUTPUT_DIR}/ca.key" 2048 &> /dev/null
  openssl req -x509 -new -nodes -key "${OUTPUT_DIR}/ca.key" -subj "/CN=kube-ca" -days 365 -out "${OUTPUT_DIR}/ca.crt"
}

function generate::apiserver::cert {
  # Prepare config file for apiserver
  generate::ssl::apiserver::conf "${K8S_SERVICE_IP},${K8S_MASTER_IP}" $CLUSTER_DOMAIN "apiserver"

  # Generate api server certificate
  openssl genrsa -out "${OUTPUT_DIR}/apiserver.key" 2048 &> /dev/null
  openssl req \
          -new \
          -key "${OUTPUT_DIR}/apiserver.key" \
          -subj "/CN=kube-apiserver" \
          -out "${OUTPUT_DIR}/apiserver.csr" \
          -config "${OUTPUT_DIR}/apiserver.cnf"
  openssl x509 \
          -req \
          -in "${OUTPUT_DIR}/apiserver.csr" \
          -CA "${OUTPUT_DIR}/ca.crt" \
          -CAkey "${OUTPUT_DIR}/ca.key" \
          ${CA_SERIAL_PARAM} \
          -out "${OUTPUT_DIR}/apiserver.crt" \
          -days 365 \
          -extensions v3_req \
          -extfile "${OUTPUT_DIR}/apiserver.cnf"
}

function generate::kubelet::cert {
  NAME="kubelet-${1}"
  generate::ssl::kubelet::conf "${1}" "${NAME}"

  openssl genrsa -out "${OUTPUT_DIR}/${NAME}.key" 2048 &> /dev/null
  openssl req \
          -new \
          -key "${OUTPUT_DIR}/${NAME}.key" \
          -out "${OUTPUT_DIR}/${NAME}.csr" \
          -subj "/CN=${1}" \
          -config "${OUTPUT_DIR}/${NAME}.cnf"

  openssl x509 \
          -req \
          -in "${OUTPUT_DIR}/${NAME}.csr" \
          -CA "${OUTPUT_DIR}/ca.crt" \
          -CAkey "${OUTPUT_DIR}/ca.key" \
          ${CA_SERIAL_PARAM} \
          -out "${OUTPUT_DIR}/${NAME}.crt" \
          -days 365 \
          -extensions v3_req \
          -extfile "${OUTPUT_DIR}/${NAME}.cnf"
}

function generate::admin::cert {
  openssl genrsa -out "${OUTPUT_DIR}/admin.key" 2048 &> /dev/null
  openssl req -subj "/CN=${ADMIN_USERNAME}" -new \
    -key "${OUTPUT_DIR}/admin.key" \
    -out "${OUTPUT_DIR}/admin.csr"

  openssl x509 -req -days 365 \
    -in "${OUTPUT_DIR}/admin.csr" \
    -CA "${OUTPUT_DIR}/ca.crt" \
    -CAkey "${OUTPUT_DIR}/ca.key" \
    ${CA_SERIAL_PARAM} \
    -out "${OUTPUT_DIR}/admin.crt"
}

function generate::user::cert {
  USER=$1
  openssl genrsa -out "${OUTPUT_DIR}/${USER}.key" 2048 &> /dev/null
  openssl req -subj "/CN=${USER}" -new \
    -key "${OUTPUT_DIR}/${USER}.key" \
    -out "${OUTPUT_DIR}/${USER}.csr"

  openssl x509 -req -days 365 \
    -in "${OUTPUT_DIR}/${USER}.csr" \
    -CA "${OUTPUT_DIR}/ca.crt" \
    -CAkey "${OUTPUT_DIR}/ca.key" \
    ${CA_SERIAL_PARAM} \
    -out "${OUTPUT_DIR}/${USER}.crt"
}

set -o errexit

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Output dir: '${OUTPUT_DIR}' doesn't exist. Creating..."
  mkdir $OUTPUT_DIR &> /dev/null
fi

# Generate ca if it doesn't exist
if [ ! -f "${OUTPUT_DIR}/ca.crt" ]; then
  echo "CA certificate doesn't exist. Generating..."
  generate::ca::cert

  # Generate merge key/cert file needed by apache proxy
  cat "${OUTPUT_DIR}/ca.crt" "${OUTPUT_DIR}/ca.key" > "${OUTPUT_DIR}/ca-merged.crt"
fi

if [ -f "${OUTPUT_DIR}/ca.srl" ]; then
  CA_SERIAL_PARAM="-CAserial ${OUTPUT_DIR}/ca.srl"
fi

if [ "${1}" == "apiserver" ]; then
  generate::apiserver::cert
  echo "Generated api server certificate."
elif [ "${1}" == "kubelet" ]; then
  if [ ! -z "$2" ]; then
    generate::kubelet::cert "${2}"
    echo "Generated kubelet certificate. IP: ${2}"
  else
    echo "Kubelet IP needed to generate certs."
  fi
elif [ "${1}" == "admin" ]; then
  generate::admin::cert
  echo "Generated admin certificate."
elif [ "${1}" == "user" ]; then
  if [ ! -z "$2" ]; then
    generate::user::cert "${2}"
    echo "Generated user certificate. Name: ${2}"
  else
    echo "User name needed to generate certs."
  fi
elif [ "${1}" == "copy" ]; then
  sudo cp $OUTPUT_DIR/apiserver.crt $COPY_TO
  sudo cp $OUTPUT_DIR/apiserver.key $COPY_TO
  sudo cp $OUTPUT_DIR/ca-merged.crt $COPY_TO
  sudo cp $OUTPUT_DIR/ca.key $COPY_TO
  sudo cp $OUTPUT_DIR/ca.crt $COPY_TO
  echo "Copied base (apiserver, ca) certificates from '${OUTPUT_DIR}' to '${COPY_TO}'"
fi
