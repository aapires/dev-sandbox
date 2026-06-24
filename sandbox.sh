#!/usr/bin/env bash
# Sobe (se preciso) e entra no sandbox central. Vários ./sandbox.sh em paralelo
# (um por terminal/projeto) rodam como processos independentes no MESMO container.
#   ./sandbox.sh                 -> Claude Code na raiz /workspace
#   ./sandbox.sh <projeto>       -> Claude Code já dentro de /workspace/<projeto>
#   ./sandbox.sh codex [proj]    -> Codex CLI (na raiz ou já no projeto)
#   ./sandbox.sh shell [proj]    -> bash dentro do sandbox (opcional: já no projeto)
#   ./sandbox.sh setup <proj>    -> cria o venv Linux do projeto e instala as deps
#   ./sandbox.sh sync            -> (re)gera compose.override.yml (config desta máquina)
#   ./sandbox.sh status          -> mostra container, portas, venvs e perfis (projects.conf)
#   ./sandbox.sh backup [proj]   -> backup dos projetos "dentro+backup" (host; ver backup.sh)
#   ./sandbox.sh pull            -> baixa a imagem do appliance do registry (GHCR)
#   ./sandbox.sh build           -> (re)constrói a imagem localmente
#   ./sandbox.sh down            -> para o container (mantém venvs e login)
#   ./sandbox.sh reset           -> apaga só os venvs (recupera disco; login PRESERVADO)
#   ./sandbox.sh reset-all       -> apaga TODOS os volumes (venvs + login)
set -euo pipefail
cd "$(dirname "$0")"

# Pareia o UID/GID do container com o usuário do host (ownership do bind-mount). A imagem
# é UID-agnóstica (roda como "${SANDBOX_UID}:0"), então a MESMA imagem serve qualquer host.
# Nomes próprios: em zsh, UID/GID são variáveis readonly e não podem ser atribuídas.
export SANDBOX_UID="$(id -u)"
export SANDBOX_GID="$(id -g)"

# Nome do projeto compose fixado em compose.yml (name: sandbox) → prefixo dos volumes.
PROJECT="sandbox"

# Gera compose.override.yml a partir do que existe em ~/Projects (= ../). Mantém o core
# (compose.yml) genérico/distribuível; a config-de-máquina (máscaras de .venv por projeto +
# binds especiais de mounts.local.conf) fica neste override gitignored.
do_sync() {
  local override="compose.override.yml" extra="mounts.local.conf"
  local -a mounts=() d proj line
  # Máscara anônima para todo projeto com .venv (esconde o venv macOS do host; o venv
  # Linux vai para o volume nomeado ~/.venvs/<proj>). Pula se mounts.local.conf já cobre.
  for d in ../*/; do
    [ -d "$d/.venv" ] || continue
    proj="$(basename "$d")"
    if [ -f "$extra" ] && grep -q "/workspace/$proj/.venv" "$extra"; then continue; fi
    mounts+=("/workspace/$proj/.venv")
  done
  # Binds in-place especiais desta máquina, verbatim.
  if [ -f "$extra" ]; then
    while IFS= read -r line; do
      case "$line" in ''|\#*) continue ;; esac
      mounts+=("$line")
    done < "$extra"
  fi
  {
    echo "# GERADO por ./sandbox.sh sync — NÃO editar à mão, NÃO versionar."
    echo "# Config DESTA MÁQUINA: máscaras de .venv por projeto + binds de mounts.local.conf."
    echo "services:"
    echo "  sandbox:"
    if [ ${#mounts[@]} -eq 0 ]; then
      echo "    {}   # nenhum .venv de projeto a mascarar nesta máquina"
    else
      echo "    volumes:"
      for line in "${mounts[@]}"; do echo "      - $line"; done
    fi
  } > "$override"
  echo "compose.override.yml regenerado (${#mounts[@]} mount(s))."
}

case "${1:-claude}" in
  sync)  do_sync ;;
  pull)  docker compose pull ;;
  build) docker compose build ;;
  down)  docker compose down ;;
  reset)
    docker compose down
    docker volume rm "${PROJECT}_sandbox-venvs" 2>/dev/null \
      && echo "venvs apagados; login preservado." \
      || echo "nenhum volume de venv a apagar."
    ;;
  reset-all) docker compose down -v ;;
  shell)
    proj="${2:-}"
    workdir="/workspace${proj:+/$proj}"
    [ -n "$proj" ] && [ ! -d "../$proj" ] && { echo "projeto '../$proj' não existe" >&2; exit 1; }
    docker compose up -d
    docker exec -it -e TERM="${TERM:-xterm-256color}" -w "$workdir" sandbox bash
    ;;
  claude)
    docker compose up -d
    docker exec -it -e TERM="${TERM:-xterm-256color}" -w /workspace sandbox claude
    ;;
  codex)
    proj="${2:-}"
    workdir="/workspace${proj:+/$proj}"
    [ -n "$proj" ] && [ ! -d "../$proj" ] && { echo "projeto '../$proj' não existe" >&2; exit 1; }
    docker compose up -d
    docker exec -it -e TERM="${TERM:-xterm-256color}" -w "$workdir" sandbox codex
    ;;
  setup)
    proj="${2:-}"
    [ -z "$proj" ] && { echo "uso: $0 setup <projeto>" >&2; exit 1; }
    [ ! -d "../$proj" ] && { echo "projeto '../$proj' não existe" >&2; exit 1; }
    docker compose up -d
    # Destino do venv: in-place (.venv) só se mounts.local.conf tem um bind GRAVÁVEL para
    # /workspace/<proj>/.venv; senão named volume ~/.venvs/<proj>. NUNCA cria .venv sem
    # máscara (clobraria o venv macOS do host).
    if grep -qs ":/workspace/$proj/.venv\b" mounts.local.conf; then venv=".venv"; else venv="\$HOME/.venvs/$proj"; fi
    docker exec -w "/workspace/$proj" sandbox bash -lc '
      set -e
      venv="'"$venv"'"
      [ -d "$venv" ] || { echo ">> criando venv em $venv"; python -m venv "$venv"; }
      "$venv/bin/pip" install --upgrade pip -q
      if [ -f pyproject.toml ] || [ -f setup.py ]; then
        echo ">> pip install -e ."; "$venv/bin/pip" install -e .
      elif [ -f requirements.txt ]; then
        echo ">> pip install -r requirements.txt"; "$venv/bin/pip" install -r requirements.txt
      else
        echo ">> sem pyproject.toml/setup.py/requirements.txt — venv criado vazio"
      fi
      echo ">> pronto: $venv ($("$venv/bin/python" --version))"
    '
    ;;
  status)
    echo "== container =="
    docker ps --filter name=sandbox --format '{{.Names}}  {{.Status}}' 2>/dev/null || echo "(docker indisponível)"
    echo; echo "== portas publicadas (host -> container) =="
    docker port sandbox 2>/dev/null || echo "(container parado)"
    echo; echo "== venvs prontos =="
    docker exec sandbox bash -lc '
      ls -1 ~/.venvs 2>/dev/null | sed "s/^/  ~\/.venvs\//" || true
      for d in /workspace/*/.venv; do [ -x "$d/bin/python" ] && echo "  in-place: $d"; done 2>/dev/null
      :
    ' 2>/dev/null || echo "(container parado)"
    echo; echo "== perfis (projects.conf) =="
    if [ -f projects.conf ]; then
      while IFS= read -r line; do
        case "$line" in ''|\#*) continue ;; esac
        proj="${line%%:*}"; rest="${line#*:}"; perfil="${rest%%:*}"; paths="${rest#*:}"
        printf "  %-26s %s%s\n" "$proj" "$perfil" "${paths:+  [$paths]}"
      done < projects.conf
    else echo "  (projects.conf ausente)"; fi
    ;;
  backup)
    ./backup.sh "${2:-}"
    ;;
  *)
    # Qualquer outro argumento é tratado como nome de projeto: Claude já no diretório dele.
    proj="$1"
    [ ! -d "../$proj" ] && { echo "projeto '../$proj' não existe (use: $0 [<projeto>|codex|shell|setup|sync|status|pull|build|down|reset|reset-all])" >&2; exit 1; }
    docker compose up -d
    docker exec -it -e TERM="${TERM:-xterm-256color}" -w "/workspace/$proj" sandbox claude
    ;;
esac
