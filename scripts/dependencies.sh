# Script including code to install dependencies.

#
# CFSSL
#
# Configuration
readonly cfssl_version="${cfssl_version:-1.5.0}"
readonly cfssl_arch="${cfssl_arch:-linux_amd64}"
readonly cfssl_binaries=(cfssl-bundle cfssl-certinfo cfssl-newkey cfssl-scan cfssljson cfssl mkbundle multirootca)

# download functions
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

#
# SYSTEM DEPENDENCIES
#
install_system_dependencies () {
  ( curl --version > /dev/null && print_info "curl available" ) || \
    { print_warning "Curl not found. Installing"; sudo apt install -y curl; print_success "Curl Installed"; }
}

#
# MAIN WRAPPER
#
install_dependencies () {
  install_system_dependencies
  install_cfssl_binaries
}

print_deps_usage () {
  tput setaf 7
  cat << EOUSAGE

Installs dependencies like curl, cfssl etc. needed for phonee to run.

USAGE:
  phonee.sh deps [ACTION]

POSSIBLE ACTIONS:
  install       Installs system and other dependencies needed for phonee to run
  help          Displays help message

EOUSAGE
  tput sgr0
}

#
# MAIN ENTRYPOINT
#
parse_deps_args_and_exec () {
  argc="$#"
  # Only Argument expected is init
  (("${argc}" != 1)) && { print_usage; error_exit "Unexpected number of arguments"; }

  action="$1"
  # If only 1 argument then it should be install or help; else exit
  [[ "${action}" =~ ^(install|help)$ ]] || { print_usage; error_exit "Unexpected action '${action}' for component deps"; }

  case "${action}" in
    install )
      print_heading "Installing dependencies"
      install_dependencies
      ;;
    help )
      print_deps_usage; exit 0
      ;;
    * )
      # Should never happen
      { print_deps_usage; error_exit "Unexpected action '${action}'"; }
      ;;
  esac
}
