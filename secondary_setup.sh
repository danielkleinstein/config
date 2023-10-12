#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
cd $SCRIPT_DIR

USER=${USER:-$(id -un)}

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

cp -r $SCRIPT_DIR/home_folder/. $HOME/
