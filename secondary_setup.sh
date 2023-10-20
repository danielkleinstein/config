#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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

PYTHON_PACKAGES=("virtualenv" "requests" "boto3" "tldr")
for package in "${PYTHON_PACKAGES[@]}"; do
    echo -e "${RED}Installing $package...${NC}"
    pip3 install $package > /dev/null 2>&1
done

echo -e "${RED}Installing fzf...${NC}"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all

cp -r $SCRIPT_DIR/home_folder/. $HOME/
