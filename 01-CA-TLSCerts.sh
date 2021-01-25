#!/usr/bin/env bash

# References used in this script
# > https://technedigitale.com/archives/639
# > https://gitlab.com/gitlab-org/build/CNG/-/blob/master/cfssl-self-sign/scripts/generate-certificates
# > https://computingforgeeks.com/build-pki-ca-for-certificates-management-with-cloudflare-cfssl/
# > https://blog.cloudflare.com/introducing-cfssl/

# Script execution options
set -o errexit      # exit script when command fails
set -o nounset      # exit if using undefined variables
set -o pipefail     # exit when a command in pipe fails
# set -o xtrace       # uncomment for debugging


# ----------- CONFIGURE CERTIFICATE AUTHORITY OPTIONS BELOW ------------
# cfssl configuration
readonly cfssl_version="${cfssl_version:-1.5.0}"
readonly cfssl_arch="${cfssl_arch:-linux_amd64}"
readonly cfssl_binaries=(cfssl-bundle cfssl-certinfo cfssl-newkey cfssl-scan cfssljson cfssl mkbundle multirootca)
# common options
readonly algorithm="${algorithm:-rsa}"
readonly key_size="${key_size:-2048}"
# domain name options
# shellcheck disable=SC2018
readonly randstr=$(head /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
readonly sub_domain_prefix="${1:-${randstr}}"
readonly sub_domain="${sub_domain:-phonee.sslip.io}"
readonly domain="${sub_domain_prefix}-${sub_domain}"
# root CA options
readonly root_ca_subject=${root_ca_subject:-Root CA for ${domain}}
readonly root_ca_org=${root_ca_org:-Root CA Organization for ${domain}}
readonly root_ca_org_unit=${root_ca_org_unit:-Root CA Organization Unit for ${domain}}
readonly root_ca_country=${root_ca_country:-US}
readonly root_ca_state=${root_ca_state:-California}
readonly root_ca_location=${root_ca_location:-Sunnyvale}
readonly root_ca_expiry=${root_ca_expiry:-87600h}
# Intermediate CA options
readonly int_ca_subject=${int_ca_subject:-Intermediate CA for ${domain}}
readonly int_ca_org=${int_ca_org:-Intermediate CA Organization for ${domain}}
readonly int_ca_org_unit=${int_ca_org_unit:-Intermediate CA Organization Unit for ${domain}}
readonly int_ca_country=${int_ca_country:-US}
readonly int_ca_state=${int_ca_state:-California}
readonly int_ca_location=${int_ca_location:-Sunnyvale}
readonly int_ca_expiry=${int_ca_expiry:-43800h}
# Lead Certificate options
readonly server_wildcard_cert_subject=${server_wildcard_cert_subject:-${domain}}
readonly server_wildcard_cert_org=${server_wildcard_cert_org:-Wildcard Leaf Certificate Organization for ${domain}}
readonly server_wildcard_cert_org_unit=${server_wildcard_cert_org_unit:-Wildcard Leaf Certificate Organization Unit for ${domain}}
readonly server_wildcard_cert_country=${server_wildcard_cert_country:-US}
readonly server_wildcard_cert_state=${server_wildcard_cert_state:-California}
readonly server_wildcard_cert_location=${server_wildcard_cert_location:-Sunnyvale}
readonly server_wildcard_cert_expiry=${server_wildcard_cert_expiry:-8670h}
# ----------- DONE CONFIGURATION ---------------


# -------- IMPORTANT EXECUTION CONTEXT VARIABLES -------------
# shellcheck disable=SC2034
readonly exec_dir=$(pwd)
# shellcheck disable=SC2034
readonly script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC2034
readonly script_name=$(basename "${0}")
readonly ca_resource_dir="${script_dir}/resources/certificate_authority"
# -------- DONE EXECUTION CONTEXT VARIABLES -------------


# ----- FUNCTION DEFINITIONS---------

# ------ Functions to display error, info messages etc ---------
# Display error message and exit with non-zero exit status
error_exit () {
  print_error "$@"
  exit 1
}
# Display Heading
print_heading () {
  echo -e "\n$(tput setaf 4)$(tput setab 7)********** ${1} **********$(tput sgr0)\n"
}
# Various log level display functions
print_error () {
  echo "$(tput setaf 1)ERROR:$(tput sgr0) $1" 1>&2
}
print_warning () {
  echo "$(tput setaf 3)WARNING:$(tput sgr0) $1"
}
print_info () {
  echo "$(tput setaf 6)INFO:$(tput sgr0) $1"
}
print_success () {
  echo "$(tput setaf 2)SUCCESS:$(tput sgr0) $1"
}

# ---- Functions to install various dependencies.
# Download the cfssl binary file passed as $1
download_cfssl_binary () {
  local -r cfssl_binary="${1}"
  print_warning "${cfssl_binary} not found. Installing..."
  sudo curl --silent -L \
    "https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/${cfssl_binary}_${cfssl_version}_${cfssl_arch}" \
    -o "/usr/local/bin/${cfssl_binary}" && \
  sudo chmod +x "/usr/local/bin/${cfssl_binary}"
  print_success "${cfssl_binary} installed"
}
# Check if cfssl binary exists; if not, download it
install_cfssl_binaries () {
  for cfssl_binary in "${cfssl_binaries[@]}"; do
    ( [[ -f "/usr/local/bin/${cfssl_binary}" ]] && print_info "${cfssl_binary} available" ) || download_cfssl_binary "${cfssl_binary}"
  done
}
# Check and install various system dependencies
install_system_dependencies () {
  ( curl --version > /dev/null && print_info "curl available" ) || \
    { print_warning "Curl not found. Installing"; sudo apt install -y curl; print_success "Curl Installed"; }
}

#  ---- Functions to setup Certificate authority ------
# Generate configuration file (signing profiles) for certificate authority
generate_ca_config () {
  tee "${ca_resource_dir}/ca-config.json" <<CA_CONFIG
{
  "signing": {
    "default": {
      "expiry": "${server_wildcard_cert_expiry}"
    },
    "profiles": {
      "intermediate_ca": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment",
            "cert sign",
            "crl sign",
            "server auth",
            "client auth"
        ],
        "expiry": "${server_wildcard_cert_expiry}",
        "ca_constraint": {
            "is_ca": true,
            "max_path_len": 0,
            "max_path_len_zero": true
        }
      },
      "peer": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment",
            "client auth",
            "server auth"
        ],
        "expiry": "${server_wildcard_cert_expiry}"
      },
      "server": {
        "usages": [
          "signing",
          "digital signing",
          "key encipherment",
          "server auth"
        ],
        "expiry": "${server_wildcard_cert_expiry}"
      },
      "client": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "client auth"
        ],
        "expiry": "${server_wildcard_cert_expiry}"
      }
    }
  }
}
CA_CONFIG
  print_success "CA configuration file ${ca_resource_dir}/ca-config.json created."
}
# Generate CSRJSON file for Root Certificate Authority
generate_root_ca_csrjson () {
  tee "${ca_resource_dir}/root_ca/root_ca_csr.json" <<ROOT_CA_CSR
{
  "CN": "${root_ca_subject}",
  "key": {
    "algo": "${algorithm}",
    "size": ${key_size}
  },
  "names": [
    {
      "C": "${root_ca_country}",
      "ST": "${root_ca_state}",
      "L": "${root_ca_location}",
      "O": "${root_ca_org}",
      "OU": "${root_ca_org_unit}"
    }
  ],
  "ca": {
    "expiry": "${root_ca_expiry}"
  }
}
ROOT_CA_CSR
  print_success "Root CA CSRJSON file ${ca_resource_dir}/root_ca/root_ca_csr.json created."
}
# Generate Root CA Certificate, Key and encoded CSR from CSRJSON
generate_root_ca () {
  ( [[ -f "${ca_resource_dir}/root_ca/root_ca_csr.json" ]] && print_info "root_ca_csr.json available, skipping creation." ) || generate_root_ca_csrjson
  ( pushd "${ca_resource_dir}/root_ca" && \
    cfssl gencert -initca root_ca_csr.json | cfssljson -bare root_ca - && \
    popd && \
    print_success "Root CA created.")
}

# Generate CSRJSON file for Intermediate Certificate Authority
generate_intermediate_ca_csrjson () {
  tee "${ca_resource_dir}/intermediate_ca/intermediate_ca_csr.json" <<INTERMEDIATE_CA_CSR
{
  "CN": "${int_ca_subject}",
  "key": {
    "algo": "${algorithm}",
    "size": ${key_size}
  },
  "names": [
    {
      "C": "${int_ca_country}",
      "ST": "${int_ca_state}",
      "L": "${int_ca_location}",
      "O": "${int_ca_org}",
      "OU": "${int_ca_org_unit}"
    }
  ],
  "ca": {
    "expiry": "${int_ca_expiry}"
  }
}
INTERMEDIATE_CA_CSR
  print_success "Intermediate CA CSRJSON file ${ca_resource_dir}/intermediate_ca/intermediate_ca_csr.json created."
}
# Generate Intermediate CA Certificate, Key and encoded CSR from CSRJSON
generate_intermediate_ca () {
  ( [[ -f "${ca_resource_dir}/intermediate_ca/intermediate_ca_csr.json" ]] && print_info "intermediate_ca_csr.json available, skipping creation." ) || generate_intermediate_ca_csrjson
  ( pushd "${ca_resource_dir}/intermediate_ca" && \
    cfssl gencert -initca intermediate_ca_csr.json | cfssljson -bare intermediate_ca - && \
    print_success "Intermediate CA created." && \
    print_info "Signing Intermediate CA CSR with Root CA keys and intermediate_ca profile" && \
    cfssl sign -ca "${ca_resource_dir}/root_ca/root_ca.pem" \
      -ca-key "${ca_resource_dir}/root_ca/root_ca-key.pem" \
      -config "${ca_resource_dir}/ca-config.json" \
      -profile intermediate_ca \
      intermediate_ca.csr | cfssljson -bare intermediate_ca && \
    popd && \
    print_success "Intermediate CA created.")
}

# Generate CSRJSON file for Wildcard Server Certificate
generate_server_wildcard_certificate_csrjson () {
  tee "${ca_resource_dir}/server_wildcard_cert/server_wildcard_csr.json" <<SERVER_WILDCARD_CSR
{
  "CN": "${server_wildcard_cert_subject}",
  "key": {
    "algo": "${algorithm}",
    "size": ${key_size}
  },
  "names": [
    {
      "C": "${server_wildcard_cert_country}",
      "ST": "${server_wildcard_cert_state}",
      "L": "${server_wildcard_cert_location}",
      "O": "${server_wildcard_cert_org}",
      "OU": "${server_wildcard_cert_org_unit}"
    }
  ],
  "hosts": [
    "*.${domain}"
  ]
}
SERVER_WILDCARD_CSR
  print_success "Server Wildcard CSRJSON file ${ca_resource_dir}/server_wildcard_cert/server_wildcard_csr.json created."
}
# Generate Intermediate CA Certificate, Key and encoded CSR from CSRJSON
generate_server_wildcard_certificate () {
  ( [[ -f "${ca_resource_dir}/server_wildcard_cert/server_wildcard_csr.json" ]] && print_info "server_wildcard_csr.json available, skipping creation." ) || generate_server_wildcard_certificate_csrjson
  ( pushd "${ca_resource_dir}/server_wildcard_cert" && \
    print_info "Creating Server Wildcard Certificate with Intermediate keys and server profile" && \
    cfssl gencert -ca "${ca_resource_dir}/intermediate_ca/intermediate_ca.pem" \
      -ca-key "${ca_resource_dir}/intermediate_ca/intermediate_ca-key.pem" \
      -config "${ca_resource_dir}/ca-config.json" \
      -profile server \
      server_wildcard_csr.json | cfssljson -bare server_wildcard && \
    print_success "Server Wildcard Certificate created." && \
    print_info "Bundling Certificate chains." && \
    cat "${ca_resource_dir}/server_wildcard_cert/server_wildcard.pem" \
      "${ca_resource_dir}/intermediate_ca/intermediate_ca.pem" \
      "${ca_resource_dir}/root_ca/root_ca.pem" > server_intermediate_root_chain.pem && \
    cat "${ca_resource_dir}/server_wildcard_cert/server_wildcard.pem" \
      "${ca_resource_dir}/intermediate_ca/intermediate_ca.pem" > server_intermediate_chain.pem && \
    print_success "Server Certificate Chains created." && \
    popd )
}

main () {
  print_heading "Execution context"
  print_info "Executing directory: ${exec_dir}"
  print_info "Script directory: ${script_dir}"
  print_info "Script name: ${script_name}"

  print_heading "Installing dependencies"
  install_system_dependencies
  install_cfssl_binaries

  print_heading "Generating Certificate Authority Artifacts"
  # Create directories
  mkdir -p "${ca_resource_dir}/root_ca"
  mkdir -p "${ca_resource_dir}/intermediate_ca"
  mkdir -p "${ca_resource_dir}/server_wildcard_cert"

  # Generate CA config file if does not exist
  ( [[ -f "${ca_resource_dir}/ca-config.json" ]] && print_info "ca-config.json available, skipping creation." ) || generate_ca_config

  # Generate Root CA key, certificate and csr
  ( [[ -f "${ca_resource_dir}/root_ca/root_ca.pem" && -f "${ca_resource_dir}/root_ca/root_ca-key.pem" ]] && \
      print_info "root_ca.pem and root_ca-key.pem available, skipping creation." ) || generate_root_ca

  # Generate Intermediate CA key, certificate and csr
  ( [[ -f "${ca_resource_dir}/intermediate_ca/intermediate_ca.pem" && -f "${ca_resource_dir}/intermediate_ca/intermediate_ca-key.pem" ]] && \
      print_info "intermediate_ca.pem and intermediate_ca-key.pem available, skipping creation." ) || generate_intermediate_ca

  # Generate Wildcard Leaf Server certificate
  ( [[ -f "${ca_resource_dir}/server_wildcard_cert/server_wildcard.pem" && -f "${ca_resource_dir}/server_wildcard_cert/server_wildcard-key.pem" ]] && \
      print_info "server_wildcard.pem and server_wildcard-key.pem available, skipping creation." ) || generate_server_wildcard_certificate
}

main "$@"