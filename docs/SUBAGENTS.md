# Subagentes — desenho v2 (concorrência estilo OpenClaw)

Status: **proposta**, ainda sem implementação. Base: `feature/81-subagents-mvp` (commit 302a99c).

## 1. Decisões já tomadas

- Subagente roda como **processo próprio** (`TermAI run --subagent <runId>`). Motivo: o Lua do TermAI é single-thread; sem processo separado não há concorrência real.
- `sessions_spawn` é **assíncrono**: retorna `{status="accepted", runId}` na hora. O resultado chega depois, como anúncio (igual ao OpenClaw).
- **Clone** usa o workspace do agente pai. **Não cria pasta nova.**
- **Agente independente** tem workspace próprio, criado em `~/.TermAI/agents/<id>/` (`SOUL.md`, `IDENTITY.md`, `USER.md`). Entra em `agents.list` no config e fica reutilizável.
- Clone não grava sessão: o diretório de execução é apagado ao terminar.

## 2. Comparação com o OpenClaw (fonte: docs.openclaw.ai)

| Tema | OpenClaw | Proposta TermAI |
|---|---|---|
| Execução | fila in-process por sessão pai | processo separado por subagente |
| Concorrência | `maxConcurrent` padrão 8 | `maxConcurrent` configurável; padrão conservador no A20s, medido antes de subir |
| Admissão | `maxChildrenPerAgent` padrão 5 | igual, mais checagem de RAM disponível (`/proc/meminfo`) antes de criar o processo |
| Entrega | anúncio push de volta ao pai | anúncio injetado no contexto do pai no próximo ponto seguro (ver §5) |
| Controle | `/subagents list, log, info, kill, send, steer` | mesmos comandos, mesma semântica |
| Restart | filhos interrompidos não são relançados; o pai decide | igual; órfãos viram `failed/process_exit` |
| Stop | cancela a árvore de filhos | `kill` mata o processo do filho e de seus descendentes |
| Contexto do filho | só `AGENTS.md` | clone: identidade do pai (decisão do usuário); independente: próprio workspace |
| Profundidade | docs divergem (1 na visão geral, 5 na página de operações) | **1** no MVP; confirmar com você |

Onde podemos superar: admissão consciente de RAM e de cota da API, para aceitar mais de 8 sem derrubar o aparelho. O limite real é memória e rate limit, não o desenho.

## 3. Layout em disco

```
~/.TermAI/subagents/<runId>/
  run.json        status, pid, agentId, task, model, parent, created/started/ended
  events.jsonl    uma linha por evento: tool_start, tool_end, log, final
  result.txt      resposta final (entregue ao pai uma vez)
  stderr.log      saída de erro do processo filho
```

- `status`: `queued | running | completed | failed | killed | timeout`.
- Escrita atômica: gravar `run.json.tmp` e renomear. Evita JSON corrompido no Termux se o processo morrer no meio.

## 4. Ciclo de vida

1. **spawn**: grava `run.json` como `queued`. Se houver vaga, inicia o processo: `io.popen("lua5.4 ... run --subagent <id> >stderr.log 2>&1 & echo $!")` e grava o pid.
2. **scheduler**: roda no ponto seguro do pai (fim de tool/turno e antes de pedir input). Confere `kill -0 <pid>`, avança filas, aplica `runTimeoutSeconds`.
3. **fim**: o filho escreve `result.txt` e `status`. O pai lê uma vez e injeta o anúncio.
4. **kill**: `kill -TERM <pid>`; o pai marca `killed`. O Lua não captura sinais, então o estado é definido pelo pai.
5. **órfãos**: no startup, `running` com pid morto vira `failed/process_exit`.

## 5. Como o orquestrador recebe o resultado (ponto em aberto)

Hoje `ui/input.lua` lê com `io.read(1)` bloqueante. Enquanto o usuário não digita, o pai não acorda. Opções:

- **A (proposta inicial):** o anúncio entra no contexto no próximo ponto seguro: quando o usuário envia algo, ou no fim de uma tool. Simples e seguro. Não acorda o modelo sozinho.
- **B (depois):** leitura de entrada não bloqueante (um leitor em segundo plano escrevendo em FIFO). Permite acordar o pai automaticamente, como o OpenClaw faz. Mexe no loop de input, então é um passo separado.

## 6. Como aparece na TUI

- **Bloco de subagentes** abaixo da conversa, uma linha por execução ativa, atualizado no lugar (`\27[nA` + `\27[K`):
  `⬤ sub-3f2a · researcher · Read | a.lua`
  Com mais de N execuções: `... +K em fila`.
- **Conclusão:** uma linha `✓ sub-3f2a concluído`. A resposta final **não** aparece na TUI, só no contexto do pai (como você pediu).
- **Erro:** uma linha `✗ sub-3f2a falhou: <motivo>`.
- **Comandos:** `/subagents list`, `/subagents log <id> [n]`, `/subagents info <id>`, `/subagents kill <id>`.
- Spinner e raciocínio do subagente continuam ocultos (como na versão atual).

## 7. Limites para o Galaxy A20s

- Cada processo filho custa memória (Lua + curl). Medir RSS antes de definir o padrão.
- Admissão: recusar criar processo novo se `MemAvailable` estiver abaixo do limite configurado.
- Padrão proposto: `maxConcurrent = 3`. Subir é uma decisão sua, depois da medição.

## 8. Testes e CI

- Unitários: fila e admissão com processos simulados; máquina de estados de `run.json`; kill e órfãos.
- Integração: spawn real de `lua5.4` com provedor falso (stub local) e verificação do anúncio.
- Workflow `tests.yml` já roda todos os specs; os novos entram automaticamente.

## 9. Perguntas para decidir

1. **Sessão do clone:** apagar ao terminar (como você pediu). Isso impede `/subagents log` depois do fim. Confirmar?
2. **Entrega:** começar pela opção A (no próximo ponto seguro) e deixar a B para depois?
3. **Padrões:** `maxConcurrent = 3` e profundidade `1` no MVP?
4. **Agente independente criado pelo orquestrador:** precisa da sua confirmação antes de gravar arquivos e alterar o config?
