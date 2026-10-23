# Paridade com OpenClaw — subagentes

Fonte: documentação oficial `docs.openclaw.ai/tools/subagents` (índice e páginas de referência).
O TermAI é uma evolução do OpenClaw em Lua. Esta matriz mostra, item por item, o que já existe,
o que falta e o que não se aplica ao TermAI, e por quê. Cada "Falta" vira uma issue ou um lote.

Legenda: **Feito** · **Parcial** · **Falta** · **N/A** (depende de infraestrutura que o TermAI não tem; registrado com a alternativa).

## 1. Conceito e ciclo de vida

| Item do OpenClaw | Status no TermAI | Observação |
|---|---|---|
| Run em background a partir de um run existente | Feito | `sessions_spawn`, processo próprio (`TermAI run --worker`) |
| Sessão própria por subagente | Feito | run.json + events.jsonl por run |
| Anúncio do resultado ao solicitante | Feito | aviso ao pai no ponto seguro; linha verde/vermelha na TUI |
| Isolamento por padrão | Feito | filho sem sessão/mensagens do pai |
| Profundidade de aninhamento configurável | Falta | hoje o filho não cria filho (profundidade fixa em 1) |
| Ponte de anúncio em cadeia (filho de filho) | Falta | depende da profundidade configurável |
| Sandboxing opcional | N/A | backends Docker/Podman/SSH do OpenClaw não existem no TermAI |

## 2. Contexto (`context`)

| Item | Status | Observação |
|---|---|---|
| `isolated` (padrão) | Feito | único modo hoje |
| `fork` (ramificar a transcrição do pai) | Falta | exige copiar `ctx.msgs` do pai até o ponto do spawn; possível |

## 3. Parâmetros de `sessions_spawn`

| Parâmetro | Status | Observação |
|---|---|---|
| `task` | Feito | |
| `taskName` (identificador estável) | Falta | útil para `subagents` referenciar o filho sem runId |
| `label` (título curto) | Falta | só exibição |
| `agentId` (outro agente configurado) | Falta | TermAI tem agentes em `tools/agents/`; mapear |
| `cwd` (diretório de trabalho do filho) | Falta | |
| `runtime` `subagent` / `acp` | N/A | ACP = harnesses externos (claude, gemini, opencode); não existe no TermAI |
| `resumeSessionId`, `streamTo` | N/A | só ACP |
| `model` (modelo do filho) | Parcial | verificar se o spawn aceita o campo e se o worker o aplica |
| `runTimeoutSeconds` | Feito (com diferença) | TermAI: padrão 600 s. OpenClaw: padrão 0 (sem prazo). Decisão pendente |
| `thinking` | Falta | |
| `thread` / `mode: "session"` | N/A | threads de canal (Discord, Telegram) — TermAI tem Telegram; ver nota |
| `mode` `run` | Feito | único modo |
| `cleanup` `delete` / `keep` | Feito | + `retain` (padrão: 7 dias ou 50 runs) |
| `expectsCompletionMessage: false` (fire-and-forget) | Falta | o filho não avisa o pai |
| `completionTarget: "parent"` (resultado privado ao pai) | Falta | |
| `sandbox: "require"` | N/A | sem sandbox |
| `visible: true` (sessão persistente no painel) | N/A | painel web do OpenClaw; TermAI tem TUI |
| `group`, `projectId`, `projectGitUrl` | N/A | painel e projetos gerenciados |
| `worktree` (git worktree gerenciado) | Falta | útil para subagentes que editam código; possível com `git worktree` |
| `placement` (nuvem) | N/A | Cloud Workers do OpenClaw |
| `attachments`, `attachAs` | Falta | |
| Sem parâmetros de canal (`target`, `to`, `replyTo`) | Feito | o filho nunca entrega direto a canal |

## 4. Ferramentas de controle (`subagents`, `sessions_list`, `sessions_history`, `session_status`)

| Item | Status | Observação |
|---|---|---|
| `list` | Feito | `subagents_listar` |
| `info` (cartão de detalhes) | Feito | formato OpenClaw; redigido |
| `log` | Feito | `subagents_log` |
| `kill` | Feito | `subagents_matar` (com confirmação) |
| `wait` (esperar um run) | Feito | `subagents_wait` (além do OpenClaw; teto 300 s) |
| `send` (mensagem a um filho em execução) | Falta | |
| `steer` (redirecionar um filho em execução) | Falta | |
| `kill all` | Falta | hoje só um por vez |
| `spawn` manual (`/subagents spawn <agentId> <task>`) | Falta | |
| `sessions_list`, `sessions_history` | Parcial | `sessoes_listar`, `sessoes_historico` existem; verificar cobertura de subagentes |
| `session_status` | Parcial | `sessao_status` existe |
| `sessions_yield` (encerrar o turno e esperar resultados) | Falta | útil para orquestrador sem polling |
| `subagents` slash command no chat | Parcial | `/subagents` existe na TUI com `gc`, `kill` etc. |

## 5. Tokens e custo

| Item | Status | Observação |
|---|---|---|
| Consumo por subagente (cartão) | **Feito neste lote** | acumulado por chamada em `agent/api/usage.lua`; gravado em rec.usage |
| Modelo mais barato para subagentes (`agents.defaults.subagents.model`) | Falta | |
| Thinking padrão para subagentes | Falta | |

## 6. Anúncio (announce)

| Item | Status | Observação |
|---|---|---|
| Resultado + status + estatísticas | Feito | cabeçalho com status, duração, tools; tokens no cartão |
| Teto de tamanho e ponteiro para o completo | Feito | 8 KB |
| `REPLY_SKIP` / `NO_REPLY` (resposta silenciosa após entrega) | Falta | evita o pai responder de novo ao aviso |
| Entrega em fila quando o pai está ocupado | Feito | espera o turno acabar |

## 7. Política de ferramentas do subagente

| Item | Status | Observação |
|---|---|---|
| Subagente sem ferramentas de sessão/mensagem por padrão | Feito | filho não cria filho nem fala com canais |
| Ferramentas de controle só no nível permitido | Feito | `subagents_matar` e `agents_criar` pedem confirmação |
| Política por profundidade | Falta | depende da profundidade configurável |

## 8. Operação: concorrência, recuperação, parada

| Item | Status | Observação |
|---|---|---|
| Limite de simultâneos | Feito | 5 no total e 5 por pai |
| Fila | Feito | |
| Timeout por run | Feito | |
| Recuperação após reinício | Parcial | run.json persistido; anúncio entregue na próxima sessão |
| Parada em cascata (`/stop` derruba filhos e netos) | Falta | depende da profundidade |
| Parada manual de um run | Feito | |

## 9. Sessões ligadas a thread (canais)

| Item | Status | Observação |
|---|---|---|
| Vincular subagente a thread de canal | N/A por enquanto | TermAI tem canal Telegram (`channels/`); a alternativa é vincular ao chat/tópico do Telegram. Lote futuro |

## Lote proposto (próximas PRs, em ordem)

1. Profundidade configurável + cadeia de anúncio + parada em cascata (itens de 1, 7, 8).
2. Contexto `fork` + `taskName` + `label` + `expectsCompletionMessage` + `completionTarget` (2, 3).
3. `send`, `steer`, `kill all`, `spawn` manual, `sessions_yield` (4).
4. `cwd` e `worktree` gerenciado com `git worktree` (3).
5. Modelo e thinking por subagente, modelo barato padrão (5).
6. `REPLY_SKIP`/resposta silenciosa, `agentId` (6, 3).
7. Decisão sobre `runTimeoutSeconds` padrão (3).

Itens N/A ficam registrados aqui para não sumirem: sandbox, ACP, painel visível, placement em nuvem, projetos gerenciados e threads de canal (com alternativa Telegram).
