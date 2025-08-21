#!/usr/bin/env bash
# ===================================================================
# Exercício 5 +Devs2Blu - Trabalho individual
# ===================================================================
# What it does:
# 1. Checks for root privileges
# 2. Installs Docker, Docker Compose, Git, and curl
# 3. Clones or updates the repo
# 4. Builds Docker images if needed or pulls updates
# 5. Runs the containers
# 6. Sets up a cron job to run this script every 5 minutes
# ===================================================================

set -euo pipefail

# -----------------------------
# Configuration
# -----------------------------
REPO_URL="https://github.com/EduHCavilha/proway-docker.git"
WORKDIR="/opt/pizzaria"
SCRIPT_PATH="$WORKDIR/deploy.sh"
CRON_LOG="/var/log/pizzaria-deploy.log"

# -----------------------------
# Simple logger
# -----------------------------
log() {
  echo "[$(date -Is)] $*"
}

# -----------------------------
# Make sure script is run as root
# -----------------------------
require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash deploy.sh"
    exit 1
  fi
}

# -----------------------------
# Install necessary packages
# -----------------------------
install_deps() {
  log "Installing Docker, docker-compose, Git, curl..."
  apt-get update -y
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git docker.io docker-compose
  systemctl enable --now docker
}

# -----------------------------
# Clone or update the repo
# -----------------------------
ensure_repo() {
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"
  if [[ -d ".git" ]]; then
    log "Updating existing repo..."
    git fetch --all --prune
    git reset --hard origin/main || true
    git pull --rebase || true
  else
    log "Cloning repo..."
    git clone "$REPO_URL" "$WORKDIR"
  fi
}

# -----------------------------
# Build images and start containers
# -----------------------------
rebuild_and_up() {
  cd "$WORKDIR"
  CURRENT_HASH="$(git rev-parse HEAD)"
  LAST_HASH_FILE=".last_deployed_commit"
  LAST_HASH=""
  [[ -f "$LAST_HASH_FILE" ]] && LAST_HASH="$(cat "$LAST_HASH_FILE" || true)"

  if [[ "$CURRENT_HASH" != "$LAST_HASH" ]]; then
    log "Commit changed: $LAST_HASH -> $CURRENT_HASH. Rebuilding all images..."
    docker-compose pull
    docker-compose build --no-cache
    echo "$CURRENT_HASH" > "$LAST_HASH_FILE"
  else
    log "No code changes. Updating base images..."
    docker-compose pull
    docker-compose build
  fi

  log "Starting containers..."
  docker-compose up -d
}

# -----------------------------
# Set up cron job to run every 5 minutes
# -----------------------------
install_cron() {
  log "Setting up cron job"
  touch "$CRON_LOG"
  chmod 664 "$CRON_LOG"
  crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab - || true
  (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/env bash $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
}

# -----------------------------
# Main
# -----------------------------
main() {
  require_root
  install_deps
  ensure_repo
  rebuild_and_up
  install_cron
  log "Deploy done! Frontend:80 | Backend:5000"
}

main "$@"
