#!/usr/bin/env bash
# Backup dos projetos de perfil "dentro+backup" (ver projects.conf). Roda NO HOST — nunca
# dentro do sandbox. Copia os caminhos declarados de ~/Projects/<proj>/ para um destino FORA
# de ~/Projects (~/sandbox-backups/<proj>/<timestamp>/), que o Claude no container não alcança,
# com rotação (mantém os RETAIN snapshots mais recentes por projeto; padrão 15).
#
#   ./backup.sh            -> faz backup de TODOS os projetos dentro+backup
#   ./backup.sh <projeto>  -> só de um projeto
set -euo pipefail
cd "$(dirname "$0")"

# Pasta de projetos: do .env (escrito pelo install.sh) ou, na falta, o diretório-pai.
[ -f .env ] && . ./.env
PROJECTS_DIR="$(cd "${PROJECTS_DIR:-..}" && pwd)"
DEST_ROOT="${SANDBOX_BACKUP_DIR:-$HOME/sandbox-backups}"   # FORA da pasta de projetos
MANIFEST="./projects.conf"
RETAIN="${SANDBOX_BACKUP_RETAIN:-15}"
TS="$(date +%Y%m%d-%H%M%S)"
only="${1:-}"

[ -f "$MANIFEST" ] || { echo "manifesto não encontrado: $MANIFEST" >&2; exit 1; }

backup_one() {
  local proj="$1" paths="$2"
  local src="$PROJECTS_DIR/$proj"
  [ -d "$src" ] || { echo "  ! $proj: diretório não existe, pulando" >&2; return; }
  [ -n "$paths" ] || { echo "  ! $proj: dentro+backup sem caminhos declarados, pulando" >&2; return; }

  local dest="$DEST_ROOT/$proj/$TS"
  mkdir -p "$dest"
  local arr rel
  IFS=',' read -ra arr <<< "$paths"   # split só aqui; não vaza p/ a rotação abaixo
  for rel in "${arr[@]}"; do
    rel="$(echo "$rel" | xargs)"   # trim
    [ -z "$rel" ] && continue
    if [ -e "$src/$rel" ]; then
      mkdir -p "$dest/$(dirname "$rel")"
      case "$rel" in
        *.db|*.sqlite|*.sqlite3)
          # Hot backup consistente via API online do SQLite (integra o WAL; seguro com o
          # app escrevendo). Cai para cp se não for um SQLite válido.
          if sqlite3 "$src/$rel" ".backup '$dest/$rel'" 2>/dev/null; then
            echo "  + $proj/$rel (sqlite .backup)"
          else
            cp -Rp "$src/$rel" "$dest/$rel"
            echo "  + $proj/$rel (cp — não era SQLite)"
          fi ;;
        *)
          cp -Rp "$src/$rel" "$dest/$rel"
          echo "  + $proj/$rel" ;;
      esac
    else
      echo "  ! $proj/$rel: não encontrado" >&2
    fi
  done

  # Rotação: mantém os RETAIN snapshots mais recentes (ordena por nome = timestamp).
  local kept
  kept="$(ls -1 "$DEST_ROOT/$proj" 2>/dev/null | sort -r | tail -n +"$((RETAIN+1))")"
  for old in $kept; do
    rm -rf "${DEST_ROOT:?}/$proj/$old"
    echo "  - rotacionado: $proj/$old"
  done
}

echo "Backup → $DEST_ROOT  (retain=$RETAIN)"
found=0
# Lê linhas projeto:perfil:caminhos, ignora comentários/vazias.
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  proj="${line%%:*}"; rest="${line#*:}"
  perfil="${rest%%:*}"; paths="${rest#*:}"
  [ "$perfil" = "dentro+backup" ] || continue
  [ -n "$only" ] && [ "$proj" != "$only" ] && continue
  found=1
  echo "[$proj]"
  backup_one "$proj" "$paths"
done < "$MANIFEST"

[ "$found" -eq 0 ] && { echo "nada a fazer (nenhum projeto dentro+backup${only:+ chamado '$only'})"; exit 0; }
echo "OK."
