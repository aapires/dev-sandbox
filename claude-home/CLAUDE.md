# Guardrails globais do sandbox (valem para TODOS os projetos)

Você está rodando dentro do **sandbox central**, montado em `/workspace` (= `~/Projects` do
host). Você está **murado do host** (sem acesso ao SO, a `~/.ssh`, a outros apps, nem a nada
fora de `/workspace`). Dentro de `/workspace` você **pode ver o código e os dados de negócio** —
isso é esperado e ajuda a debugar.

## Pode ver dados de negócio

- Você **pode** ler e inspecionar dados de negócio dentro de `/workspace`: PDFs, bancos
  (`*.db`/`*.sqlite`, inclusive via `sqlite3`), saídas, relatórios. Para corrigir bugs é normal
  precisar olhar o que a aplicação gravou — faça isso à vontade.

## Nunca leia segredos

- **Nunca** leia credenciais/segredos: `**/.env`, `**/credentials.json`, `**/token.json`,
  `**/.browser_profile/**`. São chaves, não dados de trabalho; estão bloqueados por política.
  Se precisar de uma config que está num `.env`, **peça o valor ao operador** em vez de ler.

## Dado sensível mora fora do mount (e não existe aqui)

- Alguns projetos mantêm o dado real **fora** de `/workspace` de propósito (dados sensíveis /
  PII de terceiros), em local host-only não montado. Lá o dado simplesmente **não existe** aqui
  dentro. O código o acessa por uma **env var** (`<PROJ>_DATA_DIR` etc.) que aponta para um
  caminho ausente no sandbox. **Trate a ausência como esperada** — não tente "consertar" criando
  dados nem mover dado para dentro do repo. Para debugar a base real desses projetos, o trabalho
  é feito pelo operador **no host**.

## Nunca exfiltre dados ativamente

- Não use `curl`/`wget`/`POST`, email, nem `git push` para enviar dados a destinos externos.
  O que você lê já serve ao seu trabalho aqui; não há motivo para transmiti-lo para fora.

## Código sai por Git — push é do host

- Você edita o working tree montado e faz `commit`. O `push` **não** funciona aqui (sem
  credencial, de propósito) — é feito pelo operador, do host. Após o commit, avise o operador
  que o `push` está pronto para ele fazer do host.

## LLM de pipeline é local

- LLM usado por pipelines de processamento de dado roda **local** (Ollama via
  `host.docker.internal`, KoboldCpp por IP). Não mande dado real para serviços externos.
