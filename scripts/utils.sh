# Common Utility Functions used by phonee

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
  echo "$(tput setaf 1)ERROR:$(tput sgr0) $*" 1>&2
}
print_warning () {
  echo "$(tput setaf 3)WARNING:$(tput sgr0) $*"
}
print_info () {
  echo "$(tput setaf 6)INFO:$(tput sgr0) $*"
}
print_success () {
  echo "$(tput setaf 2)SUCCESS:$(tput sgr0) $*"
}


