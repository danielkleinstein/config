# Overview

My personal repository for a new server/machine setup.

## Quick Setup
```bash
if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    SUDO=""
fi

$SUDO apt update -y
$SUDO apt install software-properties-common -y
$SUDO apt install git -y
git clone https://github.com/danielkleinstein/config.git
$SUDO ./config/setup.sh
rm -rf config
```