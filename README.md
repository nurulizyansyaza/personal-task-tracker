# Personal Task Tracker - Docker & CI/CD

Orchestration repository for the Personal Task Tracker project. Contains Docker Compose configurations for local development, staging, and production environments, plus GitHub Actions CI/CD workflows.

## Architecture

| Component | Repository | Tech |
|-----------|-----------|------|
| Core Logic | [personal-task-tracker-core](https://github.com/nurulizyansyaza/personal-task-tracker-core) | TypeScript npm package |
| Backend API | [personal-task-tracker-api](https://github.com/nurulizyansyaza/personal-task-tracker-api) | NestJS + TypeORM + MariaDB |
| Frontend | [personal-task-tracker-frontend](https://github.com/nurulizyansyaza/personal-task-tracker-frontend) | NextJS + Tailwind + React Query |
| Docker/CI/CD | This repo | Docker Compose + GitHub Actions |

## Quick Start (Local Development)

### Prerequisites
- Docker & Docker Compose
- Git

### 1. Clone all repositories
```bash
mkdir personal-task-tracker-project && cd personal-task-tracker-project
git clone https://github.com/nurulizyansyaza/personal-task-tracker.git
git clone https://github.com/nurulizyansyaza/personal-task-tracker-core.git
git clone https://github.com/nurulizyansyaza/personal-task-tracker-api.git
git clone https://github.com/nurulizyansyaza/personal-task-tracker-frontend.git
```

### 2. Build core package
```bash
cd personal-task-tracker-core
npm install && npm run build
cd ..
```

### 3. Install dependencies for API and Frontend
```bash
cd personal-task-tracker-api && npm install && cd ..
cd personal-task-tracker-frontend && npm install && cd ..
```

### 4. Start with Docker Compose
```bash
cd personal-task-tracker
cp .env.local.example .env
docker compose -f docker-compose.local.yml up --build
```

### 5. Access
- **App**: http://localhost
- **API**: http://localhost:3000
- **Swagger Docs**: http://localhost:3000/api/docs

## Environments

| Environment | Compose File | Trigger |
|-------------|-------------|---------|
| Local | `docker-compose.local.yml` | Manual |
| Staging | `docker-compose.staging.yml` | Auto on `staging` branch push |
| Production | `docker-compose.production.yml` | Manual via GitHub Actions |

## CI/CD Flow

1. **Push to sub-repo `main`** → GitHub Actions builds & tests → syncs to this repo's `staging` + `main` branches
2. **Staging branch push** → Auto-builds Docker images → Pushes to ECR → Deploys to staging EC2
3. **Production deployment** → Manual trigger via GitHub Actions `workflow_dispatch`

## AWS Infrastructure

See [AWS-INFRASTRUCTURE.md](./AWS-INFRASTRUCTURE.md) for detailed setup guide.

## GitHub Secrets Setup

See the [AWS Infrastructure doc](./AWS-INFRASTRUCTURE.md#github-secrets-required) for the full list of required secrets.

## Assumptions & Trade-offs

- **Single EC2 per environment**: For free tier. In production, would use ECS/Fargate for auto-scaling.
- **Redis on EC2**: Runs as Docker container to avoid ElastiCache costs. In production, would use ElastiCache.
- **Shared RDS**: One RDS instance with separate databases for staging/production to stay within free tier.
- **No HTTPS**: Would add SSL/TLS with ACM + ALB or Let's Encrypt in a real production setup.
- **No domain**: Using Elastic IP directly. Would add Route53 + domain in production.

## What I Would Improve With More Time

- Add HTTPS with AWS Certificate Manager + ALB
- Use ECS Fargate for container orchestration instead of bare EC2
- Add ElastiCache for Redis instead of Docker-hosted Redis
- Implement blue-green or rolling deployments
- Add comprehensive E2E tests with Playwright
- Set up CloudWatch dashboards and SNS alerting
- Add database migration scripts (TypeORM migrations instead of synchronize)
- Implement rate limiting and API authentication
- Add Terraform/CDK for infrastructure-as-code
