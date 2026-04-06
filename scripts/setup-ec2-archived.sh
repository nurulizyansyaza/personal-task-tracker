#!/bin/bash
# ============================================
# EC2 Instance Setup Script
# ============================================
# Run this on a fresh Amazon Linux 2023 / AL2 EC2 instance
# Usage: chmod +x setup-ec2.sh && ./setup-ec2.sh
# ============================================

set -e

DOCKER_COMPOSE_VERSION="v2.24.0"

install_docker() {
  echo "Updating system..."
  sudo yum update -y

  echo "Installing Docker..."
  sudo yum install -y docker
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo usermod -aG docker ec2-user
}

install_docker_compose() {
  echo "Installing Docker Compose..."
  local platform
  platform="$(uname -s)-$(uname -m)"
  sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${platform}" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

  mkdir -p ~/.docker/cli-plugins
  sudo curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${platform}" -o ~/.docker/cli-plugins/docker-compose
  sudo chmod +x ~/.docker/cli-plugins/docker-compose
}

install_aws_cli() {
  echo "Installing AWS CLI..."
  sudo yum install -y aws-cli
}

setup_project_directory() {
  echo "Setting up project directory..."
  mkdir -p /home/ec2-user/personal-task-tracker/nginx
  cd /home/ec2-user/personal-task-tracker
}

print_next_steps() {
  echo ""
  echo "Setup complete. Next steps:"
  echo "1. Configure AWS CLI: aws configure"
  echo "2. Copy docker-compose and nginx configs"
  echo "3. Create .env file with your environment variables"
  echo "4. Log out and log back in for Docker group to take effect"
}

install_docker
install_docker_compose
install_aws_cli
setup_project_directory
print_next_steps
