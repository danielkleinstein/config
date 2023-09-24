#!/bin/bash

for arg in "$@"; do
  case $arg in
    --override-sudo-check)
      OVERRIDE_SUDO_CHECK=true
      ;;
    *)
      # If an unrecognized argument is passed, error out
      echo "Error: Unrecognized argument: $arg"
      exit 1
      ;;
  esac
done

if [ "$EUID" -eq 0 ] && [ "$OVERRIDE_SUDO_CHECK" = false ]; then
  echo "This script should not be run as root or with sudo. Exiting."
  exit 1
fi

pip3 install virtualenv

# Fish AWS CLI autocomplete
mkdir -p /home/ec2-user/fish/completions
cat > /home/ec2-user/.config/fish/completions/aws.fish <<EOL
function __fish_complete_aws
    env COMP_LINE=(commandline -pc) aws_completer | tr -d ' '
end

complete -c aws -f -a "(__fish_complete_aws)"
EOL

