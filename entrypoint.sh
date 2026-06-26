#!/usr/bin/env bash
# Boot do sandbox. Roda como o UID arbitrário do host (compose: user "${SANDBOX_UID}:0").
set -e

# --- passwd dinâmico ---------------------------------------------------------
# O UID de runtime (ex.: 501 do host) normalmente NÃO tem linha em /etc/passwd →
# git/npm/claude reclamam de "$USER/$HOME desconhecido". Se faltar, insere uma entrada
# apontando para o HOME já preparado na imagem. /etc/passwd é group-writable (grupo 0).
if ! getent passwd "$(id -u)" >/dev/null 2>&1; then
  echo "dev:x:$(id -u):0:sandbox dev:${HOME:-/home/dev}:/bin/bash" >> /etc/passwd 2>/dev/null || true
fi
export HOME="${HOME:-/home/dev}"

# --- guardrails frescos sobre o ~/.claude persistido (preserva login) --------
mkdir -p "$HOME/.claude" "$HOME/.codex"
cp -f /opt/claude-guardrails/CLAUDE.md     "$HOME/.claude/CLAUDE.md"     2>/dev/null || true
cp -f /opt/claude-guardrails/settings.json "$HOME/.claude/settings.json" 2>/dev/null || true

# Hooks (ex.: statusline com o uso da janela de contexto). Frescos da imagem a cada boot,
# sobre o ~/.claude persistido. Referenciados pelo settings.json acima.
if [ -d /opt/claude-guardrails/hooks ]; then
  mkdir -p "$HOME/.claude/hooks"
  cp -f /opt/claude-guardrails/hooks/* "$HOME/.claude/hooks/" 2>/dev/null || true
fi

# Identidade git para `commit` no sandbox (vinda do compose; NÃO é segredo). Sem
# credential.helper/token aqui, `push` segue impossível — o push é o gate humano no host.
[ -n "${GIT_USER_NAME:-}" ]  && git config --global user.name  "$GIT_USER_NAME"  || true
[ -n "${GIT_USER_EMAIL:-}" ] && git config --global user.email "$GIT_USER_EMAIL" || true

exec "$@"
