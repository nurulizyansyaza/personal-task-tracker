# AWS Infrastructure Setup Guide

## Architecture Overview

Both **staging** and **production** environments use identical architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS VPC                               │
│                   CIDR: 10.0.0.0/16                         │
│                                                              │
│  ┌──────────────────────────┐  ┌──────────────────────────┐ │
│  │    Public Subnet          │  │    Private Subnet         │ │
│  │    10.0.1.0/24           │  │    10.0.2.0/24           │ │
│  │                          │  │                          │ │
│  │  ┌────────────────────┐  │  │  ┌────────────────────┐  │ │
│  │  │   EC2 t2.micro     │  │  │  │   RDS db.t3.micro  │  │ │
│  │  │                    │  │  │  │   MariaDB           │  │ │
│  │  │  ┌──────────────┐  │  │  │  │                    │  │ │
│  │  │  │   Docker      │  │  │  │  │  staging_db       │  │ │
│  │  │  │  ┌─────────┐  │  │  │  │  │  production_db   │  │ │
│  │  │  │  │ Nginx   │  │  │  │  │  └────────────────────┘  │ │
│  │  │  │  │ API     │  │  │  │  │                          │ │
│  │  │  │  │ Frontend│  │  │  └──────────────────────────┘ │
│  │  │  │  │ Redis   │  │  │                                │
│  │  │  │  └─────────┘  │  │                                │
│  │  │  └──────────────┘  │  │                                │
│  │  └────────────────────┘  │                                │
│  │                          │                                │
│  └──────────────────────────┘                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## AWS Free Tier Resources Used

| Service | Tier | Free Tier Limit | Usage |
|---------|------|----------------|-------|
| **EC2** | t2.micro | 750 hrs/month (12 months) | 1 instance per environment |
| **RDS** | db.t3.micro | 750 hrs/month (12 months), 20GB | 1 instance, separate DBs |
| **ECR** | - | 500MB storage (always free) | Docker image registry |
| **CloudWatch** | - | 10 metrics, 10 alarms (always free) | Basic monitoring |
| **VPC** | - | Free | Networking |
| **Elastic IP** | - | Free when attached to running instance | 1 per EC2 |
| **S3** | - | 5GB (12 months) | Optional: backups |

### ⚠️ Cost Optimization Notes
- **EC2**: 750 hours covers 1 instance 24/7. For 2 environments, consider stopping staging when not in use.
- **RDS**: Share 1 RDS instance with separate databases for staging and production to stay within free tier.
- **Elastic IP**: Free only when associated with a running instance. Release when EC2 is stopped.

## Step-by-Step Setup

### 1. VPC Setup

```bash
# Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ptt-vpc}]'

# Create Public Subnet
aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.1.0/24 --availability-zone ap-southeast-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ptt-public}]'

# Create Private Subnet
aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.2.0/24 --availability-zone ap-southeast-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ptt-private}]'

# Create Internet Gateway
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ptt-igw}]'
aws ec2 attach-internet-gateway --internet-gateway-id <igw-id> --vpc-id <vpc-id>

# Create Route Table for Public Subnet
aws ec2 create-route-table --vpc-id <vpc-id> --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=ptt-public-rt}]'
aws ec2 create-route --route-table-id <rt-id> --destination-cidr-block 0.0.0.0/0 --gateway-id <igw-id>
aws ec2 associate-route-table --route-table-id <rt-id> --subnet-id <public-subnet-id>
```

### 2. Security Groups

```bash
# EC2 Security Group
aws ec2 create-security-group --group-name ptt-ec2-sg --description "EC2 for Task Tracker" --vpc-id <vpc-id>

# Allow SSH (restrict to your IP in production)
aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 22 --cidr 0.0.0.0/0

# Allow HTTP
aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 80 --cidr 0.0.0.0/0

# Allow HTTPS (for future SSL)
aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 443 --cidr 0.0.0.0/0

# RDS Security Group
aws ec2 create-security-group --group-name ptt-rds-sg --description "RDS for Task Tracker" --vpc-id <vpc-id>

# Allow MariaDB from EC2 SG only
aws ec2 authorize-security-group-ingress --group-id <rds-sg-id> --protocol tcp --port 3306 --source-group <ec2-sg-id>
```

### 3. RDS MariaDB

```bash
# Create DB Subnet Group
aws rds create-db-subnet-group \
  --db-subnet-group-name ptt-db-subnet \
  --db-subnet-group-description "Task Tracker DB Subnet" \
  --subnet-ids <private-subnet-id-1> <private-subnet-id-2>

# Create RDS Instance (Free Tier)
aws rds create-db-instance \
  --db-instance-identifier ptt-mariadb \
  --db-instance-class db.t3.micro \
  --engine mariadb \
  --engine-version "11.4" \
  --master-username admin \
  --master-user-password <your-secure-password> \
  --allocated-storage 20 \
  --storage-type gp2 \
  --vpc-security-group-ids <rds-sg-id> \
  --db-subnet-group-name ptt-db-subnet \
  --no-publicly-accessible \
  --backup-retention-period 7 \
  --no-multi-az
```

After RDS is available, create separate databases:
```sql
CREATE DATABASE task_tracker_staging;
CREATE DATABASE task_tracker_production;
```

### 4. ECR Repositories

```bash
# Create API ECR repo
aws ecr create-repository --repository-name ptt-api --image-scanning-configuration scanOnPush=true

# Create Frontend ECR repo
aws ecr create-repository --repository-name ptt-frontend --image-scanning-configuration scanOnPush=true
```

### 5. EC2 Instance

```bash
# Launch EC2 (Amazon Linux 2023, t2.micro)
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name <your-key-pair> \
  --security-group-ids <ec2-sg-id> \
  --subnet-id <public-subnet-id> \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ptt-staging}]'

# Allocate and Associate Elastic IP
aws ec2 allocate-address --domain vpc
aws ec2 associate-address --instance-id <instance-id> --allocation-id <eip-alloc-id>
```

Then SSH in and run the setup script:
```bash
scp scripts/setup-ec2.sh ec2-user@<ip>:/home/ec2-user/
ssh ec2-user@<ip>
chmod +x setup-ec2.sh && ./setup-ec2.sh
```

### 6. CloudWatch Monitoring

```bash
# Enable detailed monitoring
aws ec2 monitor-instances --instance-ids <instance-id>

# Create CPU Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name ptt-cpu-high \
  --alarm-description "CPU > 80% for 5 min" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=InstanceId,Value=<instance-id>

# Create RDS connection alarm
aws cloudwatch put-metric-alarm \
  --alarm-name ptt-rds-connections \
  --alarm-description "RDS connections > 50" \
  --metric-name DatabaseConnections \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=DBInstanceIdentifier,Value=ptt-mariadb
```

## GitHub Secrets Required

Set these in each repository's Settings → Secrets:

### Sub-repos (api, core, frontend)
| Secret | Description |
|--------|-------------|
| `DOCKER_REPO_PAT` | GitHub Personal Access Token with repo access to docker repo |

### Docker repo (personal-task-tracker)
| Secret | Description |
|--------|-------------|
| `DOCKER_REPO_PAT` | GitHub PAT for checking out sub-repos |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `AWS_REGION` | e.g., `ap-southeast-1` |
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `STAGING_EC2_HOST` | Staging EC2 public IP/domain |
| `STAGING_EC2_SSH_KEY` | SSH private key for staging EC2 |
| `STAGING_API_URL` | e.g., `http://staging.yourdomain.com` |
| `PRODUCTION_EC2_HOST` | Production EC2 public IP/domain |
| `PRODUCTION_EC2_SSH_KEY` | SSH private key for production EC2 |
| `PRODUCTION_API_URL` | e.g., `http://yourdomain.com` |

## CI/CD Flow Diagram

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  API Repo   │     │  Core Repo  │     │ Frontend Repo│
│  (main)     │     │  (main)     │     │  (main)      │
└──────┬──────┘     └──────┬──────┘     └──────┬───────┘
       │                   │                    │
       │    Push to main triggers CI            │
       ▼                   ▼                    ▼
  ┌──────────────────────────────────────────────────┐
  │         GitHub Actions: Build & Test              │
  └──────────────────────────────────┬───────────────┘
                                     │
                        Sync to Docker Repo
                                     │
              ┌──────────────────────┴────────────────────┐
              ▼                                           ▼
    ┌─────────────────┐                        ┌─────────────────┐
    │  Docker Repo    │                        │  Docker Repo    │
    │  (staging)      │                        │  (main)         │
    └────────┬────────┘                        └────────┬────────┘
             │                                          │
        Auto Deploy                              Manual Deploy
             │                                    (workflow_dispatch)
             ▼                                          ▼
    ┌─────────────────┐                        ┌─────────────────┐
    │  AWS Staging    │                        │  AWS Production │
    │  EC2 + RDS      │                        │  EC2 + RDS      │
    └─────────────────┘                        └─────────────────┘
```
