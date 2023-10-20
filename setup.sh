#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
cd $SCRIPT_DIR

if command -v apt > /dev/null 2>&1; then
    PACKAGE_MANAGER="apt-get"
elif command -v yum > /dev/null 2>&1; then
    PACKAGE_MANAGER="yum"

    pushd /etc/yum.repos.d/
    wget --no-check-certificate https://download.opensuse.org/repositories/shells:fish:release:3/CentOS_7/shells:fish:release:3.repo
    popd
else
    echo "Neither apt nor yum found. Exiting..."
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root using sudo.${NC}"
   exit 1
fi

echo -e "${GREEN}Updating $PACKAGE_MANAGER repositories...${NC}"
$PACKAGE_MANAGER update -y > /dev/null

echo -e "${GREEN}Installing apt-utils...${NC}"
$PACKAGE_MANAGER install apt-utils -y > /dev/null 2>&1

echo -e "${GREEN}Installing coreutils...${NC}"
$PACKAGE_MANAGER install coreutils -y > /dev/null 2>&1

echo -e "${GREEN}Installing yum-utils...${NC}"
$PACKAGE_MANAGER install yum-utils -y > /dev/null 2>&1

echo -e "${GREEN}Installing dialog...${NC}"
$PACKAGE_MANAGER install dialog -y > /dev/null 2>&1

echo -en "${GREEN}Installing fish shell...${NC}"
$PACKAGE_MANAGER install fish -y > /dev/null

if ! grep -q "^/usr/bin/fish$" /etc/shells; then
    echo "/usr/bin/fish" | sudo tee -a /etc/shells
fi

chsh -s /usr/bin/fish $ORIGINAL_USER
if id "ec2-user" &>/dev/null; then
    chsh -s /usr/bin/fish "ec2-user"
elif id "ubuntu" &>/dev/null; then
    chsh -s /usr/bin/fish "ubuntu"
fi

echo -e " ${GREEN}Fish shell is now installed and set as the default shell for $ORIGINAL_USER.${NC}"

UTILITIES=("python3" "python3-pip" "curl" "unzip" "golang" "vim" "tmux" "bat")
for utility in "${UTILITIES[@]}"; do
    echo -e "${GREEN}Installing $utility...${NC}"
    $PACKAGE_MANAGER install $utility -y > /dev/null 2>&1
done

# Due to bat being installed as batcat in Ubuntu
if [[ -e /usr/bin/batcat ]]; then mkdir -p ~/.local/bin && ln -s /usr/bin/batcat /usr/local/bin/bat; fi

# Install afer utils - because it needs curl
echo -e "${GREEN}Installing oh my fish...${NC}"
curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > omf-install 2>/dev/null
fish omf-install --path=~/.local/share/omf --config=~/.config/omf --noninteractive > /dev/null
rm omf-install

echo -e "${GREEN}Installing AWS CLI...${NC}"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" > /dev/null 2>&1
unzip awscliv2.zip > /dev/null
./aws/install > /dev/null
rm -rf aws*

echo -e "${GREEN}Installing kubectl...${NC}"
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" > /dev/null 2>&1
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

echo -e "${GREEN}Installing eksctl...${NC}"
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz" > /dev/null 2>&1
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp > /dev/null && rm eksctl_$PLATFORM.tar.gz

echo -e "${GREEN}Installing fzf...${NC}"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

echo -e "${GREEN}Installing aws-iam-authenticator...${NC}"
curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64 > /dev/null 2>&1
chmod +x ./aws-iam-authenticator
mv ./aws-iam-authenticator /usr/local/bin/

# Use SUDO_USER if available, otherwise default to current user.
ORIGINAL_USER=${SUDO_USER:-$(id -un)}
SKIP_OVERRIDE_FLAG_CHECK=false

if [ -z $SUDO_USER]; then
    # Support user data scripts in EC2 Amazon Linux/Ubuntu instances
    if id "ec2-user" &>/dev/null; then
        ORIGINAL_USER="ec2-user"
        SKIP_OVERRIDE_FLAG_CHECK=true
    elif id "ubuntu" &>/dev/null; then
        ORIGINAL_USER="ubuntu"
        SKIP_OVERRIDE_FLAG_CHECK=true
    fi
fi

# Set the flag if SUDO_USER is unavailable
if [[ -z "$SUDO_USER" ]] && [[ "$SKIP_OVERRIDE_FLAG_CHECK" == "false" ]]; then
    OVERRIDE_FLAG="--override-sudo-check"
else
    OVERRIDE_FLAG=""
fi

echo -e "${GREEN}Running secondary setup script...${NC}"
if [ -n "$OVERRIDE_FLAG" ]; then
    echo -e "${RED}Running secondary setup script with override flag...${NC}"
fi

su - $ORIGINAL_USER -c "$SCRIPT_DIR/secondary_setup.sh $OVERRIDE_FLAG"

echo -e "${GREEN}All tasks completed!${NC}"
