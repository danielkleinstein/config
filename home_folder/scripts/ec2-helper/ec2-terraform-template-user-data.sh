#!/bin/bash

if command -v apt > /dev/null 2>&1; then
    PACKAGE_MANAGER="apt-get"
elif command -v yum > /dev/null 2>&1; then
    PACKAGE_MANAGER="yum"
else
    echo "Neither apt nor yum found. Exiting..."
    exit 1
fi

cat << EOF >> /etc/profile.d/status.sh
function status() {
    tail -f /var/log/cloud-init-output.log
}
EOF
chmod +x /etc/profile.d/status.sh

$PACKAGE_MANAGER update -y
$PACKAGE_MANAGER install git -y

git clone https://github.com/danielkleinstein/config.git
./config/setup.sh
rm -rf config
