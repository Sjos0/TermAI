# Organização da raiz e do código legado — análise e plano

## 1. Como o OpenClaw organiza (inspeção da instalação na VPS, versão 2026.4.14)

Fonte: `/usr/lib/node_modules/openclaw` (o pacote instalado, não o repositório).

1. **Raiz mínima.** O pacote tem `CHANGELOG.md`, `LICENSE`, `README.md`, `package.json`, `openclaw.mjs`
   e pastas por papel: `dist/` (build), `docs/`, `assets/`, `scripts/`, `skills/`, `qa/`. Nenhum módulo solto na raiz.
2. **Sem pasta `legacy/`.** Código de compatibilidade fica junto do código moderno, com nome explícito:
   `config-compat`, `auth-choice-legacy`, `legacy-crypto-inspector`, `gaxios-fetch-compat`
   (encontrados em `dist/`, 14 arquivos).
3. **Legado é normalizado, não preservado.** O CHANGELOG registra que chaves antigas são canonizadas
   (ex.: alias `openai-codex/gpt-5.4-codex` → forma canônica) e que o `doctor --fix` reescreve o formato antigo
   para o novo. O código antigo é mantido só enquanto há leitura de configuração antiga.
4. **Recursos estáticos em pasta própria** (`assets/`), não na raiz.
5. **Documentação de operação em `docs/`** (inclusive `AGENTS.md`), não na raiz.

## 2. Estado do TermAI (antes desta mudança)

Raiz tinha 19 arquivos soltos: 9 módulos-fachada (`json`, `tools`, `ui`, `renderer`, `session`, `prompt`,
`models`, `memoryflush`, `config`), 3 pontos de entrada (`main`, `agente`, `agente_telegram`), `banner.txt`,
`ChatGPT.md`, `CONTEXT.md`, `README.md`, `LICENSE`, `VERSION`, `install.sh`.

Feito nesta rodada (sem risco de quebra):
- `ChatGPT.md` → `.ChatGPT/MEMORIA_OPERACIONAL.md` (o nome `ChatGPT.md` já existia lá com outro conteúdo, então não sobrescrevi).
- `banner.txt` → `assets/banner.txt` (3 caminhos trocados: `main.lua`, `ui/header.lua`, `skills_installer/ui.lua`).
  O arquivo **é usado** (banner de inicialização), então não foi apagado.

## 3. Plano faseado para os módulos-fachada (`lib/`)

Mover os 9 módulos para `lib/` exige mudar o `package.path` e tem 13 pontos de dependência de caminho:

| Ponto | Quantidade | Mudança |
|---|---|---|
| `package.path` em `main.lua` | 1 | incluir `BASE/lib/?.lua` |
| `package.path` em `commands/config_cli.lua` | 1 | incluir `lib/` |
| `package.path` em `e2e/kilo_*.lua` | 3 | incluir `./lib/?.lua` |
| Specs que definem `package.path` | 52 | trocar a linha (sed) |
| Specs que não definem `package.path` | 3 | acrescentar a linha |
| Lista de módulos em `commands/status.lua` | 1 | caminhos com `lib/` |

Critério de aceite da fase: `CI` completo verde, e2e com `ORQUESTRADOR OK` e `SUBAGENTES OK`, e `TermAI status`
mostrando todos os módulos. Pontos de entrada (`main.lua`, `agente.lua`, `agente_telegram.lua`) ficam na raiz.

## 4. O que NÃO muda

- Nomes de módulo (`require("json")` continua igual).
- Pastas por domínio (`agent/`, `tools/`, `ui/`, `commands/`, `channels/`) continuam como estão.
- Pares `models.lua` + `models/` seguem o padrão de fachada do projeto.

## 5. Status (fase 2 concluída)

- Módulos-fachada movidos para `lib/`: `json`, `tools`, `ui`, `renderer`, `session`, `prompt`, `models`, `memoryflush`, `config`.
- Raiz agora: `main.lua`, `agente.lua`, `agente_telegram.lua`, `install.sh`, `README`, `CONTEXT`, `LICENSE`, `VERSION`.
- Caminhos ajustados: `package.path` em `main.lua` e `commands/config_cli.lua`; linha de `lib/` no começo de cada teste e e2e (62 arquivos); leituras por caminho em 4 specs; lista de `commands/status.lua`.
- O `require("json")` etc. não mudou: só o lugar do arquivo.
