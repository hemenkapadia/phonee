#!/usr/bin/env bash

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace # Trace the execution of the script (debug)
fi

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    # A better class of script...
    set -o errexit  # Exit on most errors (see the manual)
    set -o nounset  # Disallow expansion of unset variables
    set -o pipefail # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace # Ensure the error trap handler is inherited

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$script_path"
        printf 'Script Parameters:      %s\n' "$script_params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            # shellcheck disable=SC2312
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}

# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
function script_trap_exit() {
    cd "$orig_cwd"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colours
    printf '%b' "$ta_none"
}

# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
# NOTE: The convention used in this script for exit codes is:
#       0: Normal exit
#       1: Abnormal exit due to external error
#       2: Abnormal exit due to script error
function script_exit() {
    if [[ $# -eq 1 ]]; then
        error "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        error "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi
    script_exit 'Missing required argument to script_exit()!' 2
}

# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
# shellcheck disable=SC2034
function script_init() {
    # Useful variables
    readonly orig_cwd="$PWD"
    readonly script_params="$*"
    readonly script_path="${BASH_SOURCE[0]}"
    script_dir="$(dirname "$script_path")"
    script_name="$(basename "$script_path")"
    readonly script_dir script_name

    # Important to always set as we use it in the exit handler
    # shellcheck disable=SC2155
    readonly ta_none="$(tput sgr0 2>/dev/null || true)"
}

# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty. The output of the
#       $ta_none variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
function colour_init() {
    if [[ -z ${no_colour-} ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2>/dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2>/dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2>/dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}

# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        readonly script_output
        exec 3>&1 4>&2 1>"$script_output" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2>/dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 1
    fi
}

# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if [[ -z ${no_colour-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}

# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function debug() {
    if [[ -n ${verbose-} ]]; then
        pretty_print "$@"
    fi
}


# DESC: Prints a header
# ARGS: $1 (required): Prints a header
# OUTS: None
function header() {
    printf "%b%b%s%b\n" "$ta_bold" "$fg_magenta" "$1" "$ta_none"
}

# DESC: Wrapper to pretty_print()
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function info() {
    pretty_print "$@" "$fg_white"
}

# DESC: Prints a waring message
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function warn() {
    pretty_print "$@" "$fg_yellow"
}

# DESC: Prints an error message
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function error() {
    pretty_print "$@" "$fg_red"
}

# DESC: Prints an success message
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function success() {
    pretty_print "$@" "$fg_green"
}

# DESC: Prints a prompt message
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function prompt() {
    pretty_print "$@" "$fg_blue" "no_newline"
}

# DESC: Prints a caution
# ARGS: $1 (required): Prints a ca
# OUTS: None
function caution() {
    printf "%b%b%b%b%s%b\n" "$ta_bold" "$ta_blink" "$bg_cyan" "$fg_red" "$1" "$ta_none"
}

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
        *:"$path_entry":*) ;;
        *)
            new_path="$new_path:$path_entry"
            ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}

# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" >/dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            script_exit "Missing dependency: $1" 1
        fi
    fi
    debug "Found dependency: $1"
    return 0
}

# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
# shellcheck disable=SC2120
function check_superuser() {
    local superuser
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        # shellcheck disable=SC2310
        if check_binary sudo; then
            debug 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                debug "Sudo: Couldn't acquire credentials ..." \
                    "${fg_red-}"
            else
                local test_euid
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        debug 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    debug 'Successfully acquired superuser credentials.'
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    if [[ ${1-} =~ ^0$ ]]; then
        local skip_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${skip_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}

# <-- BEGIN: Start writing script below this line -->

# References used in this script
# > https://technedigitale.com/archives/639
# > https://gitlab.com/gitlab-org/build/CNG/-/blob/master/cfssl-self-sign/scripts/generate-certificates
# > https://computingforgeeks.com/build-pki-ca-for-certificates-management-with-cloudflare-cfssl/
# > https://blog.cloudflare.com/introducing-cfssl/

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat <<EOF
Usage: $script_name [OPTIONS]

OPTIONS:
     -d|--domain <arg1>                     Root domain name (e.g. example.com)
     -cn|--commonname <arg1>                Subject Common Name of leaf certificate (e.g. www.example.com)
     -wc|--wildcard                         Generate a wildcard certificate for common name
     -s|--sans "<arg1>, <arg2>, ..,<argN>"  Subject Alternative Name (SAN) for leaf certificate (e.g. "sd1.example.com sd2.example.com")
     -h|--help                              Displays this help
     -v|--verbose                           Displays verbose output

EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
        -d | --domain)
            domain="$1"
            shift
            ;;
        -cn | --commonname)
            commonname="$1"
            shift
            ;;
        -s | --sans)
            sans="$1"
            shift
            ;;
        -wc | --wildcard)
            wildcard=true
            ;;
        -h | --help)
            script_usage
            exit 0
            ;;
        -v | --verbose)
            verbose=true
            ;;
        *)
            script_usage
            script_exit "Invalid argument to script: ${param}" 1
            ;;
        esac
    done
}

# DESC: Validate required parameters
# ARGS: None
# OUTS: None
function validate_params() {
    # domain and commonname are mandatory
    if [[ -z ${domain-} ]]; then
        script_usage
        script_exit "Mandatory argument 'domain' missing" 1
    fi
    if [[ -z ${commonname-} ]]; then
        script_usage
        script_exit "Mandatory argument 'commonname' missing" 1
    fi
    # ensure commonname ends with domain
    if [[ ! $commonname == *"$domain" ]]; then
        script_exit "Invalid argument: ${commonname}, argument must end with domain" 1
    fi
    # ensure there is only 1 subdomain in commonname
    if [[ $(echo "$commonname" | sed "s/${domain}//" | tr -cd '.' | wc -c) -gt 1 ]]; then
        script_exit "Invalid argument: ${commonname}, only 1 subdomain allowed" 1
    fi
    # ensure each san ends with domain
    if [[ -n ${sans-} ]]; then
        for san in $(echo "$sans" | tr "," "\n"); do
            if [[ ! $san == *"$domain" ]]; then
                script_exit "Invalid argument in sans: ${san}, argument must end with domain" 1
            fi
            # ensure there is only 1 subdomain in commonname
            if [[ $(echo "$san" | sed "s/${domain}//" | tr -cd '.' | wc -c) -gt 1 ]]; then
                script_exit "Invalid argument in sans: ${san}, only 1 subdomain allowed" 1
            fi
        done
    fi
    header "*** Creating PKI certs with the following parameters ***"
    info "Domain: $domain"
    info "Common Name: $commonname"
    if [[ -n ${sans-} ]]; then
      info "SANs: $sans"
    fi
    if [[ -n ${wildcard-} ]]; then
      info "Wildcard: $wildcard"
    fi
    success "All script argument validated successfully"
}

#DESC: Validate required dependencies
# ARGS: None
# OUTS: None
function validate_dependencies() {
  # declare local readonly variable hello
  local -r deps=(curl cfssl-bundle cfssl-certinfo cfssl-newkey cfssl-scan cfssljson cfssl mkbundle multirootca)
  for dep in "${deps[@]}"; do
    check_binary "${dep}"
  done
  success "All dependencies present"
}

# DESC: Set default values for certificate authority variables
# ARGS: None
# OUTS: None
function set_default_ca_vars() {
  # common options
  readonly algorithm="${algorithm:-rsa}"
  readonly key_size="${key_size:-2048}"
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
  # Leaf Certificate options
  readonly leaf_cert_subject=${leaf_cert_subject:-${commonname}}
  readonly leaf_cert_org=${leaf_cert_org:-Wildcard Leaf Certificate Organization for ${commonname}}
  readonly leaf_cert_org_unit=${leaf_cert_org_unit:-Wildcard Leaf Certificate Organization Unit for ${commonname}}
  readonly leaf_cert_country=${leaf_cert_country:-US}
  readonly leaf_cert_state=${leaf_cert_state:-California}
  readonly leaf_cert_location=${leaf_cert_location:-Sunnyvale}
  readonly leaf_cert_expiry=${leaf_cert_expiry:-8670h}
  # Certificate Authority directories
  readonly ca_resource_dir="${script_dir}/resources/certificate_authority"
}

# DESC: Generate CA configuration file
# ARGS: None
# OUTS: None
function generate_ca_config () {
  mkdir -p "${ca_resource_dir}/${domain}"
  tee "${ca_resource_dir}/${domain}/ca-config.json" <<CA_CONFIG
{
  "signing": {
    "default": {
      "expiry": "${leaf_cert_expiry}"
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
        "expiry": "${int_ca_expiry}",
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
        "expiry": "${leaf_cert_expiry}"
      },
      "server": {
        "usages": [
          "signing",
          "digital signing",
          "key encipherment",
          "server auth"
        ],
        "expiry": "${leaf_cert_expiry}"
      },
      "client": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "client auth"
        ],
        "expiry": "${leaf_cert_expiry}"
      }
    }
  }
}
CA_CONFIG
  debug "CA configuration file ${ca_resource_dir}/${domain}/ca-config.json created."
}

# DESC: Generate CSRJSON file for Root Certificate Authority
# ARGS: None
# OUTS: None
function generate_root_ca_csrjson () {
  mkdir -p "${ca_resource_dir}/${domain}/root_ca"
  tee "${ca_resource_dir}/${domain}/root_ca/root_ca_csr.json" <<ROOT_CA_CSR
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
  debug "Root CA CSRJSON file ${ca_resource_dir}/${domain}/root_ca/root_ca_csr.json created."
}

# DESC: Generate Root CA Certificate, Key and encoded CSR from CSRJSON
# ARGS: None
# OUTS: None
function generate_root_ca () {
  ( [[ -f "${ca_resource_dir}/${domain}/root_ca/root_ca_csr.json" ]] && debug "root_ca_csr.json available, skipping creation." ) || generate_root_ca_csrjson
  ( pushd "${ca_resource_dir}/${domain}/root_ca" && \
    cfssl gencert -initca root_ca_csr.json | cfssljson -bare root_ca - && \
    popd && \
    success "Root CA created.")
}

# DESC: Generate CSRJSON file for Intermediate Certificate Authority
# ARGS: None
# OUTS: None
function generate_intermediate_ca_csrjson () {
  mkdir -p "${ca_resource_dir}/${domain}/intermediate_ca"
  tee "${ca_resource_dir}/${domain}/intermediate_ca/intermediate_ca_csr.json" <<INTERMEDIATE_CA_CSR
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
  debug "Intermediate CA CSRJSON file ${ca_resource_dir}/${domain}/intermediate_ca/intermediate_ca_csr.json created."
}

# DESC: Generate Intermediate CA Certificate, Key and encoded CSR from CSRJSON
# ARGS: None
# OUTS: None
function generate_intermediate_ca () {
  ( [[ -f "${ca_resource_dir}/${domain}/intermediate_ca/intermediate_ca_csr.json" ]] && debug "intermediate_ca_csr.json available, skipping creation." ) || generate_intermediate_ca_csrjson
  ( pushd "${ca_resource_dir}/${domain}/intermediate_ca" && \
    cfssl gencert -initca intermediate_ca_csr.json | cfssljson -bare intermediate_ca - && \
    success "Intermediate CA created." && \
    debug "Signing Intermediate CA CSR with Root CA keys and intermediate_ca profile" && \
    cfssl sign -ca "../root_ca/root_ca.pem" \
      -ca-key "../root_ca/root_ca-key.pem" \
      -config "../ca-config.json" \
      -profile intermediate_ca \
      intermediate_ca.csr | cfssljson -bare intermediate_ca && \
    popd && \
    success "Intermediate CA certs signed using root CA key.")
}

# DESC: Generate CSRJSON file for Wildcard Server Certificate
# ARGS: None
# OUTS: None
function generate_leaf_certificate_csrjson () {
  tee "${ca_resource_dir}/${domain}/${commonname}/leaf_cert_csr.json" <<SERVER_WILDCARD_CSR
{
  "CN": "${leaf_cert_subject}",
  "key": {
    "algo": "${algorithm}",
    "size": ${key_size}
  },
  "names": [
    {
      "C": "${leaf_cert_country}",
      "ST": "${leaf_cert_state}",
      "L": "${leaf_cert_location}",
      "O": "${leaf_cert_org}",
      "OU": "${leaf_cert_org_unit}"
    }
  ],
  "hosts": [
    "${commonname}",
SERVER_WILDCARD_CSR
  if [[ -n ${wildcard-} ]]; then
    echo "    \"*.${commonname}\"," >> "${ca_resource_dir}/${domain}/${commonname}/leaf_cert_csr.json"
  fi
  if [[ -n ${sans-} ]]; then
    for san in $(echo "$sans" | tr "," "\n"); do
      echo "    \"${san}\"," >> "${ca_resource_dir}/${domain}/${commonname}/leaf_cert_csr.json"
    done
  fi
  # remove last comma
  sed -i '$ s/,$//' "${ca_resource_dir}/${domain}/${commonname}/leaf_cert_csr.json"
  tee -a "${ca_resource_dir}/${domain}/${commonname}/leaf_cert_csr.json" <<SERVER_WILDCARD_CSR
  ]
}
SERVER_WILDCARD_CSR
  debug "Leaf certificate CSRJSON file ${ca_resource_dir}/${domain}/${commonname}/leaf_cert_csr.json created."
}

# Generate Leaf Certificates
# ARGS: None
# OUTS: None
function generate_leaf_certificate () {
  ( [[ -f "${ca_resource_dir}/${domain}/${commonname}/leaf_cert_csr.json" ]] && debug "leaf_cert_csr.json available, skipping creation." ) || generate_leaf_certificate_csrjson
  ( pushd "${ca_resource_dir}/${domain}/${commonname}" && \
    debug "Creating Leaf Certificate with Intermediate keys and server profile" && \
    cfssl gencert -ca "../intermediate_ca/intermediate_ca.pem" \
      -ca-key "../intermediate_ca/intermediate_ca-key.pem" \
      -config "../ca-config.json" \
      -profile server \
      leaf_cert_csr.json | cfssljson -bare leaf_cert && \
    success "Leaf Certificate created." && \
    debug "Bundling Certificate chains." && \
    cat "leaf_cert.pem" \
      "../intermediate_ca/intermediate_ca.pem" \
      "../root_ca/root_ca.pem" > leaf_intermediate_root_chain.pem && \
    cat "leaf_cert.pem" \
      "../intermediate_ca/intermediate_ca.pem" > leaf_intermediate_chain.pem && \
    success "Server Certificate Chains created." && \
    popd )
}


# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    # setup error
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    # initialise
    script_init "$@"
    cron_init
    colour_init
    parse_params "$@"
    #lock_init system

    # validate
    validate_params
    validate_dependencies

    # setup default ca options
    set_default_ca_vars

    # bootstrap certificate authority for domain if not already done
    if [[ ! -d "${ca_resource_dir}/${domain}" ]]; then
        header "*** Bootstrapping Certificate Authority for ${domain} ***"
        generate_ca_config
        generate_root_ca
        generate_intermediate_ca
    fi

    # bootstrap certificate authority for domain if not already done
    if [[ ! -d "${ca_resource_dir}/${domain}/${commonname}" ]]; then
        mkdir -p "${ca_resource_dir}/${domain}/${commonname}"
    else
        prompt "Certificate for ${commonname} already exists. Would you like to overwrite it? (y/n): "
        read -r overwrite
        if [[ $overwrite == "y" ]]; then
            rm -rf "${ca_resource_dir:?}/${domain:?}/${commonname:?}" # https://github.com/koalaman/shellcheck/wiki/SC2115
            mkdir -p "${ca_resource_dir}/${domain}/${commonname}"
        else
            script_exit "Exiting script as requested" 0
        fi
    fi
    generate_leaf_certificate
}

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    main "$@"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
