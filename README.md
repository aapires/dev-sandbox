# dev-sandbox

Sandbox **portátil e murado** para rodar agentes de código (**Claude Code** e **Codex**)
com segurança sobre os seus projetos. Um único container long-lived, isolado do host,
que enxerga só a sua pasta de projetos — você instala numa máquina nova e já tem o
ambiente pronto.

A imagem é **project-agnostic**: não contém código nem dado nenhum. O seu código entra por
*bind-mount* em runtime; nada seu vai para a imagem ou para o registry.

> 🚀 **Primeira vez?** Comece pelo **[ONBOARDING.md](ONBOARDING.md)** (10 minutos).

## O que vem dentro

- **Agentes:** Claude Code + Codex CLI (auto-update; login feito por máquina)
- **Linguagens:** Python 3.14, Node 22, pnpm
- **Utilitários:** ripgrep, fd, jq, gh (GitHub CLI), uv, git, build-essential
- **Barra de status:** mostra modelo · diretório · uso da janela de contexto (absoluto + %)
- **Imagem multi-arch:** `linux/amd64` e `linux/arm64` (Intel e Apple Silicon)

## A muralha (por que é seguro)

- `cap_drop: ALL` + `no-new-privileges`, **sem** `docker.sock`, **sem** privileged
- O container só alcança `/workspace` (= sua pasta de projetos). Não vê `~/.ssh`, outros
  apps, nem nada do host fora dali.
- **Segredos cegos por padrão:** `.env`, `credentials.json`, `token.json`, `.browser_profile`
  são bloqueados por política (`claude-home/settings.json`).
- **`git push` não funciona de dentro** (sem credencial, de propósito): você faz `commit`
  no sandbox e o `push` é o gate humano, no host.
- Login dos agentes mora em **volumes**, nunca na imagem.

## Pré-requisitos

- [OrbStack](https://orbstack.dev) (recomendado no macOS) ou Docker Desktop, rodando.

## Instalação

Clone **dentro da sua pasta de projetos** e rode o instalador:

```bash
cd ~/Projects                                   # sua pasta de projetos
git clone https://github.com/aapires/dev-sandbox.git
cd dev-sandbox
./install.sh                                    # baixa a imagem, sobe o container
```

> Por padrão monta o diretório-pai (`~/Projects`) como `/workspace`. Para montar outra
> pasta: `PROJECTS_DIR=/caminho/dos/projetos ./install.sh`. Há trava de segurança que
> recusa montar a home ou a raiz inteiras.

Depois, o **login** (uma vez por máquina):

```bash
./sandbox.sh          # abre o Claude Code → rode /login na 1ª vez
./sandbox.sh codex    # abre o Codex       → faça o login na 1ª vez
```

## Uso diário

```bash
./sandbox.sh                 # Claude Code na raiz /workspace
./sandbox.sh <projeto>       # Claude já dentro do diretório do projeto
./sandbox.sh codex [proj]    # Codex CLI (na raiz ou no projeto)
./sandbox.sh shell [proj]    # bash dentro do sandbox
./sandbox.sh setup <proj>    # cria o venv Linux do projeto e instala as deps
./sandbox.sh sync            # após criar/clonar novos projetos (regenera máscaras de .venv)
./sandbox.sh status          # container, portas, venvs e perfis de dado
./sandbox.sh pull|build      # atualiza a imagem (baixar do GHCR | buildar local)
./sandbox.sh down            # para o container (mantém venvs e login)
```

### Venvs Python

Os `.venv` do host (macOS) são incompatíveis com o Linux do container. Crie o venv do
projeto **dentro** do sandbox: `./sandbox.sh setup <projeto>` (vai para um volume Linux,
`~/.venvs/<projeto>`, sem clobrar o `.venv` do host). O `./sandbox.sh sync` mascara
automaticamente os `.venv` de host para não vazarem binários incompatíveis.

## Perfis de dado e backup (opcional)

Para projetos com dado sensível, declare um perfil em `projects.conf`
(veja `projects.conf.example`):

- **`fora`** — dado mora fora do mount; o agente é estruturalmente cego a ele.
- **`dentro`** — o agente vê (dados regeneráveis/descartáveis).
- **`dentro+backup`** — o agente vê + snapshot externo no host via `backup.sh`
  (agende com `com.sandbox.backup.plist.example`).

## Config local vs. genérica

O repositório versiona só a infra genérica. O que é específico da sua máquina fica
*gitignored* e é gerado/local: `.env` (pasta de projetos), `compose.override.yml`
(via `sync`), `mounts.local.conf` e `projects.conf`.

## Atualizar

```bash
git pull && ./sandbox.sh pull && ./sandbox.sh down && ./sandbox.sh
```

## Licença

MIT.
