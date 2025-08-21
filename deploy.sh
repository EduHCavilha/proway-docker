#!/usr/bin/env bash
set -euo pipefail

# ===== Configurações =====
REPO_URL="https://github.com/EduHCavilha/proway-docker.git"
WORKDIR="/opt/pizzaria"
SCRIPT_PATH="$WORKDIR/deploy.sh"
CRON_LOG="/var/log/pizzaria-deploy.log"

log() { echo "[$(date -Is)] $*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Execute como root: sudo bash deploy.sh"
    exit 1
  fi
}

# ===== Instalar dependências =====
install_deps() {
  log "Instalando Docker, docker-compose, git, curl..."
  apt-get update -y
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git docker.io docker-compose
  systemctl enable --now docker
}

# ===== Clonar ou atualizar repositório =====
ensure_repo() {
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"
  if [[ -d ".git" ]]; then
    log "Atualizando repositório existente..."
    git fetch --all --prune
    git reset --hard origin/main || true
    git pull --rebase || true
  else
    log "Clonando repositório..."
    git clone "$REPO_URL" "$WORKDIR"
  fi
}

# ===== Rebuild automático e start =====
rebuild_and_up() {
  cd "$WORKDIR"
  CURRENT_HASH="$(git rev-parse HEAD)"
  LAST_HASH_FILE=".last_deployed_commit"
  LAST_HASH=""
  [[ -f "$LAST_HASH_FILE" ]] && LAST_HASH="$(cat "$LAST_HASH_FILE" || true)"

  if [[ "$CURRENT_HASH" != "$LAST_HASH" ]]; then
    log "Commit mudou: $LAST_HASH -> $CURRENT_HASH. Rebuild completo."
    docker-compose pull
    docker-compose build --no-cache
    echo "$CURRENT_HASH" > "$LAST_HASH_FILE"
  else
    log "Sem mudanças no código. Atualizando imagens base."
    docker-compose pull
    docker-compose build
  fi

  log "Subindo containers..."
  docker-compose up -d
}

# ===== Instalar cron =====
install_cron() {
  log "Configurando cron para rodar a cada 5 minutos"
  touch "$CRON_LOG"
  chmod 664 "$CRON_LOG"
  crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab - || true
  (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/env bash $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
}

# ===== Execução principal =====
main() {
  require_root
  install_deps
  ensure_repo
  rebuild_and_up
  install_cron
  log "Deploy concluído! Frontend:80 | Backend:5000"
}

main "$@"
