# Nomes e descrições das tools — padrão em inglês, superior ao OpenClaw

Status: **plano + inventário** (etapa 1). Nada de nome foi trocado ainda; a troca vem em etapas,
com alias, para não quebrar `disabled_tools`, permissões, hooks nem o histórico de conversas.

## 1. Princípios (pesquisa)

### 1.1 Anthropic — "Writing effective tools for AI agents" (fonte primária)
Fonte: https://www.anthropic.com/engineering/writing-tools-for-agents (Sep 2025, atualizado out/2026).

- **Escrever como onboarding:** "think of how you would describe your tool to a new hire". Tornar explícito o contexto
  implícito: formato de consulta, termos de nicho, relação entre recursos.
- **Parâmetros sem ambiguidade:** `user_id`, não `user`. Modelos de dados estritos.
- **Namespacing:** prefixo ou sufixo por serviço/recurso (`sessions_list`, `subagents_info`), para o agente escolher a tool certa.
- **Não sobrepor tools:** poucas, com propósito distinto. Consolidar fluxos frequentes numa tool só.
- **Resposta enxuta:** paginação, filtro e truncamento com padrões sensatos; se truncar, orientar o agente a usar
  buscas menores.
- **Erro acionável:** dizer o que corrigir ("Use YYYY-MM-DD"), não código opaco.
- **Medir:** a descrição muda o resultado; refinamentos pequenos têm efeito grande. Avaliar com tarefas reais.

### 1.2 OpenClaw — "Sub-agent tool reference" (docs.openclaw.ai/tools/subagents/tool-reference)
Padrões observados nas descrições:
- Cada tool abre com o que faz e **quando usar** (tabela de modos: `isolated` para trabalho independente, `fork` para trabalho que depende da conversa).
- Cada parâmetro traz: tipo, obrigatoriedade, **padrão** (`Defaults:`), limites (`Must be a non-negative integer; 0 disables`) e o que acontece quando o valor é inválido.
- **O que não fazer** explícito (`sessions_spawn does not accept channel-delivery params`).
- **Recuperação de erro** explícita: quando não repetir a chamada (`Do not repeat the spawn merely because ... timed out`).
- Exemplos em JSON reais.

### 1.3 OpenCode — tools em arquivos `.txt` por tool (repositório sst/opencode, `packages/opencode/src/tool/`)
Padrões observados (as descrições são curtas, mas com regras de uso firmes):
- Cada descrição tem `Usage:` com regras numeradas.
- **Regra de roteamento entre tools:** "IMPORTANT: this tool is for terminal operations... DO NOT use it for file operations" e "avoid find, grep, cat, head, tail — use the dedicated tools".
- **Pré-condição explícita:** `edit` exige `read` antes; "prefer edit to write for existing files".
- **Paginação visível:** `read` retorna linhas com número, limite padrão de 2000 linhas, linhas longas truncadas, diretório lista filhos com `/`.
- **Paralelismo explícito:** "multiple independent commands should be called in parallel, not chained with &&".
- Fonte desta seção: citação de trechos em issues e artigos (não li o repositório diretamente); tratar como referência, não como texto literal.

### 1.4 Síntese: o que a nossa descrição precisa ter (e superar)
Ordem obrigatória de cada descrição, em inglês:
1. **O que faz** (uma frase, verbo de ação).
2. **Quando usar** e **quando NÃO usar** — apontando a tool certa para cada caso (roteamento entre tools, como o OpenCode faz).
3. **Parâmetros** com tipo, padrão, limite e formato (estilo OpenClaw), nomes sem ambiguidade (estilo Anthropic).
4. **Saída:** formato, truncamento, paginação (estilo OpenCode `read`).
5. **Erros e recuperação:** o que significa cada erro e o que fazer (estilo OpenClaw e Anthropic).
6. **Exemplo** de chamada real.

O que supera o OpenClaw: (a) fronteira explícita com as tools vizinhas, (b) orientação de eficiência de contexto
(Anthropic), (c) um teste que trava a presença das seções 1-6 em toda descrição (lint), para a qualidade não regredir.

## 2. Inventário atual (21 tools)

Nome exposto hoje → título em português/inglês → arquivo.

| # | Nome atual | Idioma do nome | Arquivo | Ação |
|---|---|---|---|---|
| 1 | `Exec` | EN | tools/exec.lua | manter; reescrever descrição |
| 2 | `Read` | EN | tools/read/init.lua | manter; reescrever |
| 3 | `Grep` | EN | tools/grep.lua | manter; reescrever |
| 4 | `Find` | EN | tools/find.lua | manter; reescrever |
| 5 | `List` | EN | tools/list.lua | manter; reescrever |
| 6 | `Write` | EN | tools/write.lua | manter; reescrever |
| 7 | `Edit` | EN | tools/editor.lua | manter; reescrever |
| 8 | `calcular` | **PT** | tools/calculator.lua | **renomear para `calculate`**, alias `calcular` |
| 9 | `sessoes_listar` | **PT** | tools/sessions.lua | **renomear para `sessions_list`**, alias `sessoes_listar` |
| 10 | `sessoes_historico` | **PT** | tools/sessions.lua | **renomear para `sessions_history`**, alias `sessoes_historico` |
| 11 | `sessao_status` | **PT** | tools/sessions.lua | **renomear para `session_status`**, alias `sessao_status` |
| 12 | `pesquisar_web` | **PT** | tools/web.lua | **renomear para `web_search`**, alias `pesquisar_web` |
| 13 | `web_fetch` | EN | tools/web_fetch.lua | manter; reescrever |
| 14 | `memory_search` | EN | tools/memory.lua | manter; reescrever |
| 15 | `skill` | EN | tools/skills.lua | manter; reescrever |
| 16 | `restart` | EN | tools/restart.lua | manter; reescrever |
| 17 | `todo_write` | EN | tools/todo.lua | manter; reescrever |
| 18 | `sessions_spawn` | EN | tools/subagents/tools_def.lua | manter; reescrever (já é a mais completa) |
| 19 | `subagents_listar` | **PT** | tools/subagents/tools_def.lua | **renomear para `subagents_list`**, alias `subagents_listar` |
| 20 | `subagents_info` | EN | tools/subagents/tools_def.lua | manter; reescrever (cartão OpenClaw) |
| 21 | `subagents_log` | EN | tools/subagents/tools_def.lua | manter; reescrever |
| 22 | `subagents_wait` | EN | tools/subagents/tools_def.lua | manter; reescrever |
| 23 | `subagents_matar` | **PT** | tools/subagents/tools_def.lua | **renomear para `subagents_kill`**, alias `subagents_matar` |
| 24 | `agents_criar` | **PT** | tools/agents.lua | **renomear para `agents_create`**, alias `agents_criar` |

Total: 24 nomes registrados (contando as 4 de subagentes separadas). Oito nomes em português (8, 9, 10, 11, 12, 19, 23, 24).
Os títulos e descrições de todas são em português (ou misturados), e precisam ser reescritos em inglês.

## 3. Estratégia de nomes: canônico em inglês + alias antigo

Por que alias e não rename seco:
- `disabled_tools` (config do usuário) guarda nomes; se o nome mudar, a tool desativada volta a ficar ativa.
- Permissões e hooks (`tools/exec/permissions/check.lua`, `INTERNAL_AUTO`) comparam pelo nome.
- Histórico de conversas e memória gravados com o nome antigo.

Mecanismo (etapa 2 do plano):
1. `tools.register(canonical, ...)` registra o nome em inglês.
2. `tools.alias(legacy, canonical)` registra o nome antigo apontando para o mesmo handler.
3. Toda checagem por nome (`disabled_tools`, permissão, hook, INTERNAL_AUTO) passa por `tools.canonical(name)` antes de comparar.
4. `tools.registry` lista **só os canônicos** (o modelo vê só inglês); os aliases existem para chamadas antigas.
5. Teste: cada alias resolve para o mesmo handler; `disabled_tools` com nome antigo continua desativando a tool;
   a lista do modelo não contém nomes em português.

## 4. Etapas

| Etapa | Entrega | Risco | Teste |
|---|---|---|---|
| 1 (esta PR) | Plano, pesquisa, inventário | nenhum (só doc) | — |
| 2 | Mecanismo de alias + `canonical` + checagens por nome canonicalizadas | médio (permissão) | mutação: sem `canonical` a spec falha; alias resolve; `disabled_tools` antigo funciona |
| 3 | Renomear as 8 tools em português (com alias) | baixo (com alias) | a lista do modelo só tem inglês; chamada com nome antigo ainda funciona |
| 4 | Reescrever as descrições das 24 tools (6 seções cada) | baixo | lint: toda descrição tem "Use when", "Do not use", parâmetros com padrão, erros, exemplo |
| 5 | Avaliação: tarefas reais, comparar taxa de erro de tool antes e depois | — | métricas de erro de tool e de chamada errada |

Etapas 2 a 4 são código: cada uma com CI completo. Etapa 1 é doc.

## 5. Critério de "superior ao OpenClaw"

Uma descrição é considerada igual ou superior quando:
- tem as seis seções (o que faz, quando usar, quando não usar, parâmetros com padrão, saída e erros, exemplo);
- aponta a tool vizinha certa para cada caso de fronteira;
- trava o nome de cada parâmetro sem ambiguidade (`session_id`, não `id`);
- o lint do teste passa para todas as tools.

## 6. Decisão final: sem alias (registrada pelo usuário)

Decisão do usuário: **nomes somente em inglês, sem alias** para o nome antigo. O usuário assume as consequências,
registradas abaixo. Isto substitui a estratégia de alias das seções 3 e 4 (etapa 2 não foi feita).

Renomeações aplicadas:
calcular → calculate · sessoes_listar → sessions_list · sessoes_historico → sessions_history ·
sessao_status → session_status · pesquisar_web → web_search · subagents_listar → subagents_list ·
subagents_matar → subagents_kill · agents_criar → agents_create

Consequências (aceitas):
1. **Configuração salva com o nome antigo deixa de valer.** `disabled_tools` com `calcular`, `pesquisar_web` etc.
   não desativa mais nada: a tool volta a ficar ativa sem aviso. Quem desativou uma tool precisa trocar o nome.
2. **Agentes já criados** com `disabled_tools = { "agents_criar" }` ficam sem a proteção (o nome novo é `agents_create`).
3. **Permissões de ferramentas internas** usam o nome novo (`subagents_list`, `subagents_kill`, `agents_create`).
   Chamadas antigas gravadas no histórico de conversas referem o nome antigo; ao reabrir uma sessão, o modelo
   pode tentar o nome antigo e receber "ferramenta não existe" (com a lista de nomes atuais, graças ao #66).
4. **Memória e notas** do próprio agente que citem os nomes antigos ficam desatualizadas.
5. **Nenhum histórico de rename no registro de tools** — quem olhar `tools.registry` só vê nomes em inglês.

## 7. Status da etapa 4 (descrições em inglês)

Concluída: as 24 descrições e os textos dos parâmetros estão em inglês. Cada descrição tem o que faz,
quando usar ("Use it..."), quando NÃO usar ("Do not use it..."), e exemplo quando o parâmetro pede.
O lint `tests/tools_descriptions_spec.lua` (139 checagens) trava: nomes em inglês, seções obrigatórias,
tamanho entre 120 e 1400 caracteres, e nenhum marcador de português em descrição ou parâmetro.
Mutação: uma descrição em português faz o lint falhar.

Fora desta etapa, para decisão futura: os nomes dos parâmetros continuam em português onde são
contrato (`nome`, `identidade`, `funcoes`, `linhas`). Renomear exige mudar o handler e a chamada do modelo.

## 8. Parâmetros em inglês (feito depois da etapa 4)

Os parâmetros de tool que estavam em português foram renomeados, sem alias (decisão do usuário):
`agents_create`: nome→name, identidade→identity, funcoes→functions, confirmado→confirmed;
`subagents_log`: linhas→lines.

Consequências aceitas: chamadas antigas no histórico com os nomes em português deixam de funcionar
(o campo obrigatório some e a tool recusa a chamada com a mensagem de campo obrigatório).
Agentes já criados não são afetados: o registro e os arquivos do workspace não mudam.

Não renomeado, de propósito: `tool.nome` em `tools/error_feedback/validator.lua`. É o nome da tool
lido do parser de XML (protocolo interno), não um parâmetro de schema. Mudar quebra o parsing de todas as tools.
