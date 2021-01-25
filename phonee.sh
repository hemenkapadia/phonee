#!/usr/bin/env bash

# -------- IMPORTANT SCRIPT EXECUTION OPTIONS -------------
set -o errexit      # exit script when command fails
set -o nounset      # exit if using undefined variables
set -o pipefail     # exit when a command in pipe fails
# set -o xtrace       # uncomment for debugging


# -------- IMPORTANT EXECUTION CONTEXT VARIABLES -------------
# shellcheck disable=SC2034
readonly exec_dir=$(pwd)
# shellcheck disable=SC2034
readonly script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC2034
readonly script_name=$(basename "${0}")
readonly resources_root="${script_dir}/resources"
readonly orgs_root="${script_dir}/orgs"
# -------- DONE EXECUTION CONTEXT VARIABLES -------------


# -------- SOURCE OTHER SCRIPTS -------------
# shellcheck source=scripts/utils.sh
source "${script_dir}/scripts/utils.sh"
# shellcheck source=scripts/dependencies.sh
source "${script_dir}/scripts/dependencies.sh"
# shellcheck source=scripts/organization.sh
source "${script_dir}/scripts/organization.sh"
# -------- DONE SOURCING -----------------

print_usage () {
  tput setaf 7
  cat << EOUSAGE

Phonee (Phony Enterprise Environment) is used to create a simulated enterprise organization's
network and systems like LDAP, OpenID IDP, etc. which can help test your applications in real
world environment settings.

USAGE:
  phonee.sh [COMPONENT ACTION] [component_id] [OPTIONS]

POSSIBLE COMPONENTS:
  deps          Dependencies (Top level)
                Supported Actions [install|help]
  org           Organization. (Top level component under which all other components live)
                Supported Actions [create|list|info|destroy|help]
  ca            Certificate Authority (Organization Level)
                Supported Actions [create|info|install_root|uninstall_root|destroy|help]
  cert          Certificate (Organization Level)
                Supported Actions [create|info|http_serve|validate|destroy|help]

POSSIBLE OPTIONS:
  --help        Show help message for Phonee

EOUSAGE
  tput sgr0
}

parse_args_and_exec () {
  argc="$#"

  # If arguments < 1; exit
  (("${argc}" < 1)) && { print_usage; error_exit "Unexpected number of arguments"; }

  # First argument has to be component.
  component="$1"
  # If only 1 argument then it should be help; else exit
  (("${argc}" == 1)) && [[ "${component}" != "--help" ]] && { print_usage; error_exit "Unexpected argument: '${component}'"; }
  # if cmd is help; display help and exit
  [[ "${component}" == "--help" ]] && { print_usage; exit 0; }
  # Check that argument is in the permissible list
  [[ "${component}" =~ ^(deps|org|ca|cert|help)$ ]] || { print_usage; error_exit "Unexpected component '${component}'"; }

  # with components handled focus on actions
  action="$2"
  case "${component}" in
    deps )
      [[ "${action}" =~ ^(install|help)$ ]] || { print_usage; error_exit "Unexpected action '${action}' for component '${component}'"; }
      # pop the component argument from the list (component and action)
      shift
      parse_deps_args_and_exec "${@}";
      ;;
    org )
      [[ "${action}" =~ ^(create|list|info|destroy|help)$ ]] || { print_usage; error_exit "Unexpected action '${action}' for component '${component}'"; }
      # pop the component argument from the list (component and action)
      shift
      parse_org_args_and_exec "${@}";
      ;;
    ca )
      [[ "${action}" =~ ^(create|info|install_root|uninstall_root|destroy|help)$ ]] || { print_usage; error_exit "Unexpected action '${action}' for component '${component}'"; }
      # pop the component argument from the list (component and action)
      shift
      ;;
    cert )
      [[ "${action}" =~ ^(create|info|http_serve|validate|destroy|help)$ ]] || { print_usage; error_exit "Unexpected action '${action}' for '${component}'"; }
      # pop the component argument from the list (component and action)
      shift
      ;;
    * )
      # Should never happen
      { print_usage; error_exit "Unexpected component '${component}'"; }
      ;;
  esac
}



function main () {
  print_heading "Execution context"
  print_info "Executing directory: ${exec_dir}"
  print_info "Script directory: ${script_dir}"
  print_info "Script name: ${script_name}"

  # Create main directories
  mkdir -p "${resources_root}"
  mkdir -p "${orgs_root}"

  parse_args_and_exec "${@}"
}

main "${@}"