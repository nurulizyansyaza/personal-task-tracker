#!/usr/bin/env bash
# ============================================
# Local Docker Setup Script
# ============================================
# Prepares build contexts and starts all services locally.
# Mirrors the CI/CD "Build core & prepare Docker contexts" step.
# Usage: ./scripts/local-docker.sh [up|down|restart]
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

API_DIR="$PROJECT_ROOT/personal-task-tracker-api"
FE_DIR="$PROJECT_ROOT/personal-task-tracker-frontend"
CORE_DIR="$PROJECT_ROOT/personal-task-tracker-core"

ACTION="${1:-up}"
shift 2>/dev/null || true
EXTRA_ARGS="$*"

cleanup() {
  echo ""
  echo "[cleanup] Removing core copies from API and Frontend directories..."
  rm -rf "$API_DIR/personal-task-tracker-core"
  rm -rf "$FE_DIR/personal-task-tracker-core"

  # Restore original package.json references
  if [ -f "$API_DIR/package.json.bak" ]; then
    mv "$API_DIR/package.json.bak" "$API_DIR/package.json"
    echo "[cleanup] Restored API package.json"
  fi
  if [ -f "$FE_DIR/package.json.bak" ]; then
    mv "$FE_DIR/package.json.bak" "$FE_DIR/package.json"
    echo "[cleanup] Restored Frontend package.json"
  fi
  echo "[cleanup] Done."
}

prepare_contexts() {
  echo "[prepare] Building core package..."
  cd "$CORE_DIR"
  npm install --silent
  npm run build --silent
  echo "[prepare] Core built successfully."

  echo "[prepare] Copying core into API and Frontend build contexts..."
  cp -r "$CORE_DIR" "$API_DIR/personal-task-tracker-core"
  cp -r "$CORE_DIR" "$FE_DIR/personal-task-tracker-core"

  # Backup and update package.json references (file:../ -> file:./)
  cp "$API_DIR/package.json" "$API_DIR/package.json.bak"
  cp "$FE_DIR/package.json" "$FE_DIR/package.json.bak"
  sed -i '' 's|file:../personal-task-tracker-core|file:./personal-task-tracker-core|' "$API_DIR/package.json"
  sed -i '' 's|file:../personal-task-tracker-core|file:./personal-task-tracker-core|' "$FE_DIR/package.json"
  echo "[prepare] Build contexts ready."
}

case "$ACTION" in
  up)
    # Ensure .env exists
    if [ ! -f "$ORCH_DIR/.env" ]; then
      echo "[setup] Copying .env.local.example to .env..."
      cp "$ORCH_DIR/.env.local.example" "$ORCH_DIR/.env"
    fi

    prepare_contexts
    trap cleanup EXIT

    echo ""
    echo "[docker] Starting all services..."
    cd "$ORCH_DIR"
    docker compose -f docker-compose.local.yml up --build $EXTRA_ARGS
    ;;

  down)
    cd "$ORCH_DIR"
    docker compose -f docker-compose.local.yml down $EXTRA_ARGS
    cleanup
    ;;

  restart)
    cd "$ORCH_DIR"
    docker compose -f docker-compose.local.yml down
    cleanup
    prepare_contexts
    trap cleanup EXIT
    docker compose -f docker-compose.local.yml up --build -d
    ;;

  build)
    prepare_contexts
    trap cleanup EXIT
    cd "$ORCH_DIR"
    docker compose -f docker-compose.local.yml build $EXTRA_ARGS
    ;;

  *)
    echo "Usage: $0 [up|down|restart|build]"
    echo ""
    echo "  up       Build and start all containers (default)"
    echo "  down     Stop containers and clean up build contexts"
    echo "  restart  Stop, rebuild, and start all containers"
    echo "  build    Build images without starting"
    exit 1
    ;;
esac
