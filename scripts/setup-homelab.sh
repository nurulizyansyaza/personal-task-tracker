#!/bin/bash
# ============================================
# Homelab Server Setup Script
# ============================================
# Run this on a fresh Ubuntu/Debian homelab server
# Usage: chmod +x setup-homelab.sh && ./setup-homelab.sh
# ============================================

set -e

DOCKER_COMPOSE_VERSION="v2.24.0"

install_docker() {
  echo "Updating system..."
  sudo apt-get update -y

  echo "Installing Docker prerequisites..."
  sudo apt-get install -y ca-certificates curl gnupg

  echo "Adding Docker GPG key..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo "Adding Docker repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  echo "Installing Docker..."
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo systemctl start docker
  sudo systemctl enable docker
  sudo usermod -aG docker "$USER"
}

install_docker_compose() {
  echo "Installing Docker Compose standalone..."
  local platform
  platform="$(uname -s)-$(uname -m)"
  sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${platform}" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

  mkdir -p ~/.docker/cli-plugins
  sudo curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${platform}" -o ~/.docker/cli-plugins/docker-compose
  sudo chmod +x ~/.docker/cli-plugins/docker-compose
}

setup_firewall() {
  echo "Configuring firewall (ufw)..."
  sudo apt-get install -y ufw
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow 3000/tcp
  echo "y" | sudo ufw enable
}

setup_project_directory() {
  echo "Setting up project directory..."
  mkdir -p ~/personal-task-tracker/nginx
  cd ~/personal-task-tracker
}

print_next_steps() {
  echo ""
  echo "Setup complete. Next steps:"
  echo "1. Copy docker-compose and nginx configs to ~/personal-task-tracker/"
  echo "2. Create .env file with your environment variables"
  echo "3. Login to GHCR: echo <token> | docker login ghcr.io -u <username> --password-stdin"
  echo "4. Log out and log back in for Docker group to take effect"
  echo "5. (Optional) Set up reverse proxy with SSL (Caddy or Nginx + Let's Encrypt)"
}

install_docker
install_docker_compose
setup_firewall
setup_project_directory
print_next_steps
