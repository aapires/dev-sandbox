#!/usr/bin/env bash
# Instalador do sandbox numa máquina nova. Idempotente: pode rodar de novo sem dano.
#
# Define QUAL pasta vira /workspace (o sandbox enxerga só ela):
#   PROJECTS_DIR=~/Projects ./install.sh        (recomendado, explícito)
# Sem PROJECTS_DIR, assume o diretório-PAI deste repo (convenção: clone dentro da sua
# pasta de projetos, ex.: ~/Projects/dev-sandbox → monta ~/Projects). Há uma trava de
# segurança: recusa montar $HOME ou / inteiros.
#
# Por padrão BAIXA a imagem do registry (GHCR). Para buildar local: SANDBOX_BUILD=1 ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "== Sandbox · instalação =="

# 1. Pré-requisitos -----------------------------------------------------------
command -v docker >/dev/null 2>&1 || {
  echo "ERRO: Docker não encontrado. Instale o OrbStack (https://orbstack.dev) ou Docker Desktop." >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  echo "ERRO: o Docker não está rodando. Abra o OrbStack/Docker Desktop e rode de novo." >&2
  exit 1
}

# 2. Pasta de projetos a montar (com trava de segurança) ----------------------
PROJECTS_DIR="${PROJECTS_DIR:-$(cd .. && pwd)}"
PROJECTS_DIR="$(cd "$PROJECTS_DIR" 2>/dev/null && pwd || true)"
[ -n "$PROJECTS_DIR" ] && [ -d "$PROJECTS_DIR" ] || {
  echo "ERRO: PROJECTS_DIR inválido. Use: PROJECTS_DIR=/caminho/dos/projetos ./install.sh" >&2
  exit 1
}
if [ "$PROJECTS_DIR" = "$HOME" ] || [ "$PROJECTS_DIR" = "/" ]; then
  echo "ERRO: recusando montar '$PROJECTS_DIR' (home/raiz inteiros) como /workspace." >&2
  echo "      Aponte para a sua pasta de projetos: PROJECTS_DIR=~/Projects ./install.sh" >&2
  exit 1
fi
export PROJECTS_DIR
echo ">> /workspace = $PROJECTS_DIR"

# 3. Identidade do host (UID-agnóstico) + git p/ commits no sandbox -----------
export SANDBOX_UID="$(id -u)"
export SANDBOX_GID="$(id -g)"
export GIT_USER_NAME="${GIT_USER_NAME:-$(git config --global user.name  2>/dev/null || true)}"
export GIT_USER_EMAIL="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
echo ">> host UID=$SANDBOX_UID  git=\"${GIT_USER_NAME:-?}\" <${GIT_USER_EMAIL:-?}>"

# 5. Persiste PROJECTS_DIR em .env (o Compose lê sozinho → ./sandbox.sh usa a mesma pasta)
printf 'PROJECTS_DIR=%s\n' "$PROJECTS_DIR" > .env

# 6. Imagem: build local OU pull do registry ----------------------------------
if [ "${SANDBOX_BUILD:-0}" = "1" ]; then
  echo ">> buildando imagem localmente..."
  docker compose build
else
  echo ">> baixando imagem do registry..."
  docker compose pull || {
    echo "ERRO: pull falhou. Se a imagem for privada: 'docker login ghcr.io' (token c/ read:packages)." >&2
    echo "      Ou builde localmente:  SANDBOX_BUILD=1 ./install.sh" >&2
    exit 1
  }
fi

# 7. Config desta máquina (máscaras de .venv por projeto) ---------------------
./sandbox.sh sync

# 8. Sobe o container ---------------------------------------------------------
docker compose up -d
echo ">> sandbox no ar."

# 9. Login (uma vez por máquina; credenciais NUNCA entram na imagem) ----------
cat <<'EOF'

== Pronto. Falta só o login (uma vez por máquina) ==
  ./sandbox.sh         # Claude Code  → na 1ª vez rode:  /login
  ./sandbox.sh codex   # Codex CLI    → na 1ª vez faça o login

Uso diário:
  ./sandbox.sh <projeto>     # Claude já no diretório do projeto
  ./sandbox.sh shell         # bash dentro do sandbox
  ./sandbox.sh sync          # após criar/clonar novos projetos
  ./sandbox.sh status        # estado do container, portas e venvs
EOF
