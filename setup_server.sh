#!/usr/bin/env bash
#
# setup_server.sh
# Automated server provisioning script for Ubuntu Server.
#
# What this script does:
#   1. Set timezone to Asia/Jakarta
#   2. Update & upgrade system packages
#   3. Install Git, Curl, Zip, Python3, and pip3
#   4. Install Docker Engine + Docker Compose plugin
#
# Usage:
#   chmod +x setup_server.sh
#   sudo ./setup_server.sh
#
# Tested on: Ubuntu 20.04 / 22.04 / 24.04
set -euo pipefail

log() {
  echo -e "\n\033[1;32m==> $1\033[0m\n"
}

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root or with sudo: sudo ./setup_server.sh"
  exit 1
fi

# -----------------------------------------------------------------------------
# 1. Set timezone to Asia/Jakarta
# -----------------------------------------------------------------------------
log "Setting timezone to Asia/Jakarta"
timedatectl set-timezone Asia/Jakarta
timedatectl status | grep "Time zone"

# -----------------------------------------------------------------------------
# 2. Update & upgrade system packages
# -----------------------------------------------------------------------------
log "Updating package lists"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

log "Upgrading installed packages"
apt-get upgrade -y

# -----------------------------------------------------------------------------
# 3. Install Git, Curl, Zip, Python3, pip3
# -----------------------------------------------------------------------------
log "Installing Git, Curl, Zip, Unzip, Python3, pip3"
apt-get install -y \
  git \
  curl \
  zip \
  unzip \
  python3 \
  python3-pip \
  ca-certificates \
  gnupg \
  lsb-release

log "Installed versions:"
git --version
curl --version | head -n 1
python3 --version
pip3 --version

# -----------------------------------------------------------------------------
# 4. Install Docker Engine + Docker Compose plugin
# -----------------------------------------------------------------------------
log "Removing any old/conflicting Docker packages (if present)"
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

log "Adding Docker's official GPG key and repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

log "Installing Docker Engine, CLI, containerd, buildx, and compose plugin"
apt-get update -y
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

log "Enabling and starting Docker service"
systemctl enable docker
systemctl start docker

# Add the invoking (non-root) user to the docker group, if applicable
TARGET_USER="${SUDO_USER:-}"
if [[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]]; then
  log "Adding user '${TARGET_USER}' to the docker group"
  usermod -aG docker "$TARGET_USER"
  echo "NOTE: Log out and log back in (or run 'newgrp docker') for this to take effect."
fi

log "Docker version:"
docker --version
docker compose version

log "Server setup complete."
echo "Timezone : $(timedatectl show -p Timezone --value)"
echo "Docker   : $(docker --version)"
echo "Done."
