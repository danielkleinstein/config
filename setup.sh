#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Use SUDO_USER if available, otherwise default to current user.
ORIGINAL_USER=${SUDO_USER:-$(id -un)}

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root using sudo.${NC}"
   exit 1
fi

echo -e "${GREEN}Updating apt-get repositories...${NC}"
apt-get update -y > /dev/null

echo -e "${GREEN}Installing apt-utils...${NC}"
apt-get install apt-utils -y > /dev/null 2>&1

echo -e "${GREEN}Installing dialog...${NC}"
apt-get install dialog -y > /dev/null 2>&1

echo -en "${GREEN}Installing fish shell...${NC}"
apt-get install fish -y > /dev/null

if ! grep -q "^/usr/bin/fish$" /etc/shells; then
    echo "/usr/bin/fish" | sudo tee -a /etc/shells
fi

chsh -s /usr/bin/fish $ORIGINAL_USER

echo -e " ${GREEN}Fish shell is now installed and set as the default shell for $ORIGINAL_USER.${NC}"

UTILITIES=("python3" "python3-pip" "curl" "unzip" "golang" "vim")
for utility in "${UTILITIES[@]}"; do
    echo -e "${GREEN}Installing $utility...${NC}"
    apt-get install $utility -y > /dev/null 2>&1
done

# Install afer utils - because it needs curl
echo -en "${GREEN}Installing oh my fish...${NC}"
curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > omf-install 2>/dev/null
fish omf-install --path=~/.local/share/omf --config=~/.config/omf --noninteractive > /dev/null
rm omf-install

echo -e "${GREEN}Installing AWS CLI...${NC}"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" > /dev/null 2>&1
unzip awscliv2.zip > /dev/null
./aws/install > /dev/null
rm -rf aws*

echo -e "${GREEN}Installing eksctl...${NC}"
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz" > /dev/null 2>&1
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp > /dev/null && rm eksctl_$PLATFORM.tar.gz

echo -e "${GREEN}Installing aws-iam-authenticator...${NC}"
curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64 > /dev/null 2>&1
chmod +x ./aws-iam-authenticator
mv ./aws-iam-authenticator /usr/local/bin/

# Set the flag if SUDO_USER is unavailable
[[ -z "$SUDO_USER" ]] && OVERRIDE_FLAG="--override-sudo-check" || OVERRIDE_FLAG=""

echo -e "${GREEN}Running secondary setup script...${NC}"
su - $ORIGINAL_USER -c "$SCRIPT_DIR/secondary_setup.sh $OVERRIDE_FLAG"

echo -e "${GREEN}All tasks completed!${NC}"
