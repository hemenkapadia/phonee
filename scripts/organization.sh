# script for Organization related functions

print_org_usage () {
  tput setaf 7
  cat << EOUSAGE

Organization is the topmost level construct in Phonee. All other components are part of the organization.

USAGE:
  phonee.sh org [ACTION] [org_id]

POSSIBLE ACTIONS:
  list          List all organizations created by Phonee
  create        Creates a new organization
  info          Display information about the Organization and its components
  destroy       Destroy an organization and all constituent components
  help          Displays help message

All actions except list require an org_id to be passed.
org_id is small string (alphabets only) of about 10 characters. It will be used in the name of all child components.

EOUSAGE
  tput sgr0
}

#
# MAIN ENTRYPOINT
#
parse_org_args_and_exec () {
  readonly argc="$#"
  readonly action="$1"

  # If only 1 argument then action has to be list or help
  (("${argc}" == 1)) && [[ "${action}" =~ ^(list|help) ]] && { print_org_usage; error_exit "Unexpected action '${action}' for component org"; }

  readonly org_id="$2"

  case "${action}" in
    list )
      echo list
      ;;
    create )
      echo create
      ;;
    info )
      echo info
      ;;
     destroy )
      echo destroy
      ;;
    help )
      echo help
      ;;
    * )
      # Should never happen
      { print_org_usage; error_exit "Unexpected action '${action}'"; }
      ;;
  esac
}

