# Onboarding — dev-sandbox (10 minutos)

Guia rápido pra rodar os agentes de código (Claude Code + Codex) num container murado,
sobre os seus projetos. Para detalhes, veja o [README](README.md).

## 1. Pré-requisito

Instale e abra o **[OrbStack](https://orbstack.dev)** (macOS) ou o Docker Desktop.
Confirme que está rodando:

```bash
docker info >/dev/null && echo OK
```

## 2. Instalar (uma vez)

Clone **dentro da sua pasta de projetos** — o pai do repo vira o `/workspace` do sandbox:

```bash
cd ~/Projects                                      # sua pasta de projetos
git clone https://github.com/aapires/dev-sandbox.git
cd dev-sandbox
./install.sh                                       # baixa a imagem e sobe o container
```

> Pasta diferente? `PROJECTS_DIR=/caminho/dos/projetos ./install.sh`

## 3. Login (uma vez por máquina)

```bash
./sandbox.sh         # abre o Claude Code → digite /login
./sandbox.sh codex   # abre o Codex       → faça o login
```

As credenciais ficam em volumes locais — nunca entram na imagem.

## 4. Dia a dia

```bash
./sandbox.sh <projeto>     # Claude já dentro do projeto
./sandbox.sh codex <proj>  # Codex no projeto
./sandbox.sh shell         # bash dentro do sandbox
./sandbox.sh setup <proj>  # cria o venv Python do projeto (Linux) e instala deps
./sandbox.sh sync          # rode após clonar/criar novos projetos
./sandbox.sh status        # container, portas, venvs
```

## 5. O que você PRECISA saber (5 pegadinhas)

1. **`git push` não funciona dentro do sandbox** (de propósito, sem credencial). Você faz
   `commit` dentro; o `push` é feito por você **no host**.
2. **Venv Python:** não use o `.venv` do host (macOS) dentro do container. Crie com
   `./sandbox.sh setup <projeto>` (vai pra um volume Linux). Rode `./sandbox.sh sync`
   depois de adicionar projetos novos.
3. **Segredos são cegos:** `.env`, `credentials.json`, `token.json`, `.browser_profile`
   são bloqueados por política. Se o agente precisar de um valor, passe você mesmo.
4. **Portas de dev:** rode na porta natural dentro do sandbox (ex.: `--port 8000`) e acesse
   no host com **+10000** → `localhost:18000` (3000→13000, 5173→15173, 8080→18080).
5. **O sandbox só enxerga `/workspace`** (sua pasta de projetos). Não alcança `~/.ssh`,
   outros apps, nem o resto do host.

## 6. Atualizar

```bash
git pull && ./sandbox.sh pull && ./sandbox.sh down && ./sandbox.sh
```

## Problemas comuns

| Sintoma | Solução |
|---|---|
| `docker info` falha | abra o OrbStack/Docker Desktop e tente de novo |
| pull pede login | a imagem é pública; rode `docker logout ghcr.io` e tente sem auth |
| "API error / 529" persistente | rede com IPv6 quebrado — já mitigado na imagem; se persistir, avise |
| venv com erro de binário | recrie dentro do sandbox: `./sandbox.sh setup <projeto>` |
