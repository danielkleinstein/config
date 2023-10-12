#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

cd $SCRIPT_DIR

# Use SUDO_USER if available, otherwise default to current user.
# Fun fact - $USER is unavailable in Ubuntu slim containers.
ORIGINAL_USER=${SUDO_USER:-$(id -un)}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root using sudo."
   exit 1
fi

apt update -y
apt install fish -y

if ! grep -q "^/usr/bin/fish$" /etc/shells; then
    echo "/usr/bin/fish" | sudo tee -a /etc/shells
fi

chsh -s /usr/bin/fish $ORIGINAL_USER

echo "Fish shell is now installed and set as the default shell for $ORIGINAL_USER."

apt install python3 python3-pip curl unzip golang vim -y

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

rm -rf aws*

# Install eksctl - per the instructions at https://github.com/eksctl-io/eksctl#for-unix
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

# Install aws-iam-authenticator
curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
chmod +x ./aws-iam-authenticator
mv ./aws-iam-authenticator /usr/local/bin/

# Set the flag if SUDO_USER is unavailable
[[ -z "$SUDO_USER" ]] && OVERRIDE_FLAG="--override-sudo-check" || OVERRIDE_FLAG=""

su - $ORIGINAL_USER -c "$SCRIPT_DIR/secondary_setup.sh $OVERRIDE_FLAG"
