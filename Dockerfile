# Sandbox central — appliance portátil para rodar agentes de código (Claude Code, Codex)
# com segurança sobre os projetos. Project-agnostic: NÃO contém código nem dado; o
# código entra por bind-mount. Pareado com o host: Python 3.14 + Node LTS.
#
# UID-AGNÓSTICO: a imagem é construída com um usuário fixo (UID 1000) mas pertencente
# ao grupo 0 (root), e TODOS os diretórios graváveis ficam group-writable. Em runtime a
# compose sobe com `user: "${SANDBOX_UID}:0"`, então a MESMA imagem baixada do GHCR roda
# como o usuário do host (qualquer UID), com HOME gravável e ownership do bind-mount
# correto — sem rebuild por máquina. Padrão "arbitrary UID" (estilo OpenShift),
# compatível com cap_drop: ALL (não precisa de escalonamento de privilégio).
FROM python:3.14-slim

LABEL org.opencontainers.image.source="https://github.com/aapires/dev-sandbox" \
      org.opencontainers.image.description="Sandbox portátil e murado para rodar agentes de código (Claude Code, Codex) com segurança sobre seus projetos." \
      org.opencontainers.image.licenses="MIT"

ARG NODE_MAJOR=22
ARG USERNAME=dev
ARG UID=1000

# Toolchain base + utilitários essenciais de dev (ripgrep, fd, jq) + deps p/ apt-https.
# fd no Debian é 'fd-find' (binário fdfind) → symlink para 'fd'.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates build-essential gnupg \
        ripgrep fd-find jq \
    && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI (gh) — repositório apt oficial.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# uv (gerenciador Python rápido) global em /usr/local/bin via pip.
RUN pip install --no-cache-dir uv

# Node LTS + npm + pnpm global (root). Claude Code e Codex vão no prefixo do usuário.
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g pnpm

# Usuário não-root no GRUPO 0 (root). HOME e dirs de estado serão group-writable para
# que qualquer UID de runtime (membro do grupo 0) consiga escrever.
RUN useradd -m -u ${UID} -g 0 -s /bin/bash ${USERNAME}

# Guardrails globais "assados" read-only; o entrypoint os reaplica em ~/.claude a cada boot.
COPY --chown=${UID}:0 claude-home/ /opt/claude-guardrails/
COPY entrypoint.sh /usr/local/bin/sandbox-entrypoint

# Prefixo npm do usuário (gravável) → Claude Code e Codex se auto-atualizam sem root.
# Não é volume: vive na camada da imagem; cada container nasce com a versão da imagem.
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global
ENV PATH=/home/${USERNAME}/.npm-global/bin:${PATH}
ENV HOME=/home/${USERNAME}

# Dirs de estado pré-criados dev:0 e group-writable. Named volumes vazios HERDAM esse
# ownership na 1ª criação → o UID arbitrário de runtime (grupo 0) escreve neles.
#   .claude  -> login Claude (volume)    .codex -> login/config Codex (volume)
#   .venvs   -> venvs Linux (volume)      .npm-global -> CLIs (camada da imagem)
# /etc/passwd group-writable: o entrypoint insere a entrada do UID corrente em runtime
# (UID arbitrário não tem linha em /etc/passwd → tools que leem $USER/$HOME falhariam).
RUN chmod +x /usr/local/bin/sandbox-entrypoint \
    && mkdir -p /home/${USERNAME}/.claude /home/${USERNAME}/.codex /home/${USERNAME}/.venvs \
    && chown -R ${UID}:0 /home/${USERNAME} \
    && chmod -R g=u /home/${USERNAME} \
    && chmod g=u /etc/passwd

WORKDIR /workspace
USER ${UID}

# Claude Code + Codex CLI no prefixo do usuário (auto-update + login por máquina).
RUN npm install -g @anthropic-ai/claude-code @openai/codex

# Entrypoint reaplica guardrails e ajusta passwd; CMD mantém o container long-lived.
ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint"]
CMD ["sleep", "infinity"]
