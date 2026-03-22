#!/bin/bash
# ============================================
# EC2 Instance Setup Script
# ============================================
# Run this on a fresh Amazon Linux 2023 / AL2 EC2 instance
# Usage: chmod +x setup-ec2.sh && ./setup-ec2.sh
# ============================================

set -e

echo "🔧 Updating system..."
sudo yum update -y

echo "🐳 Installing Docker..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

echo "🐳 Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.24.0"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Also install compose plugin
mkdir -p ~/.docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o ~/.docker/cli-plugins/docker-compose
sudo chmod +x ~/.docker/cli-plugins/docker-compose

echo "☁️ Installing AWS CLI..."
sudo yum install -y aws-cli

echo "📂 Setting up project directory..."
mkdir -p /home/ec2-user/personal-task-tracker/nginx
cd /home/ec2-user/personal-task-tracker

echo "✅ Setup complete! Please:"
echo "1. Configure AWS CLI: aws configure"
echo "2. Copy docker-compose and nginx configs"
echo "3. Create .env file with your environment variables"
echo "4. Log out and log back in for Docker group to take effect"
