# Claude — Contribution Log

Registro de contribuições do Claude (claude.ai) ao projeto TermAI.

---

## 2026-08-22 - [Correção: edit.lua lista numerada (reuso de set.lua) em vez de referência digitada]
**Contexto:** O `edit.lua` (opção 5) criado no patch anterior pedia a referência do modelo digitada em texto puro (`"Referência do modelo pra editar"`), copiando o estilo do `info.lua` antigo. O pedido original do Samuel era lista numerada pra escolher (igual à opção 2, `set.lua`), já que ele não decora o texto exato `provider/id`. Lacuna apontada pelo próprio Claude após revisão.
**Files Modified:** `commands/models/models/edit.lua` — entrada de `M.edit` agora usa `models_mod.list()` pra listar todos os modelos com número (reusando exatamente o padrão de `set.lua`: header, lista `m.ref (ctx)`, `ui.is_cancel` no `0`, range check `1..#models`, `ref = models[idx].ref`). Remove o prompt de texto puro.
**Learning (Ameno):** `models.list()` retorna itens com `.ref` e `.context_window` (models/list.lua), confirmado antes de aplicar — o código do Claude estava consistente com o existente. Ao criar fluxo de seleção, reusar o padrão já consagrado em `set.lua` em vez de inventar entrada por texto (DRY / guia de estilo do projeto).
**Prevention:** Todo menu de escolha de modelo deve listar por número (padrão `set.lua`), nunca pedir referência digitada. Ao copiar estilo de outro comando, copiar o que JÁ resolve o problema do usuário, não o fallback de argumento opcional.
**Author:** Claude (claude.ai) — apontou a lacuna e propôs o patch; Ameno (aplicação + validação de que `list()` retorna `.ref`/`.context_window`).
**Validation:** `luac5.4 -p commands/models/models/edit.lua` OK; teste funcional (script Lua isolado) listou 34 modelos com `.ref`/`.context_window`; mapeamento idx→ref ok para válido/`0` (cancela)/fora-range (inválido)/não-numérico (inválido).
**PR:** Direct commit to main.

---

## 2026-08-22 - [Editor de Modelo (opção 5) + Endurecimento da Pergunta de Reasoning]
**Contexto:** (1) A pergunta "Possui Reasoning nativo?" em `add_remote.lua` aceitava Enter vazio como padrão — e para modelo "free/contributor" fora do catálogo curado o padrão é sempre `false`. Um duplo-toque acidental no Enter (comum em teclado Android) silenciosamente decidia `reasoning=false`, causando o bug real do Samuel (modelo livre sem pensar). (2) A opção 5 do gerenciador de modelos (`info.lua`) era só-leitura; `crud.lua` nunca teve `update_model`.
**Files Modified:** `commands/models/models/add_remote.lua` (pergunta de reasoning vira loop obrigatório 's'/'n', repete se vazio/inválido, sem padrão); `models/crud.lua` (nova `update_model` — grava em `models.json` via `store.save`, sincroniza `d.active` se o modelo renomeado for o ativo); `models.lua` (raiz — expõe `M.update_model = crud.update_model`, **lacuna que o Claude deixou**: o `edit.lua` chama `models_mod.update_model` mas a função não estava na fachada do módulo `models`); `commands/models/models.lua` (fachada ganha `M.edit = edit_mod.edit`); `commands/models/menu.lua` (opção 5 → `edit`, label "Detalhes / Editar", remove `ui.pause()` redundante); `commands/models/models/edit.lua` (NOVO — editor interativo de 7 campos: nome, id, contextWindow, maxTokens, reasoning, reasoning_style, default_effort).
**Learning (Ameno):** O `edit.lua` do Claude chamava `models_mod.update_model` e `models_mod.resolve`, mas o módulo `models` (raiz) só exportava `resolve` — `update_model` existia em `crud.lua` mas NÃO estava exposto na fachada. Apliquei a correção de ligação (adicionar `M.update_model` em `models.lua`) sem a qual o editor quebraria em runtime (`attempt to call nil`). `models_mod` passado ao menu é o módulo `models` (não a fachada `commands/models/models.lua`). O `models.json` real fica em `~/.TermAI/agents/main/agent/models.json` (não `~/.TermAI/models.json`).
**Prevention:** Ao criar um novo comando que dependa de função de CRUD, confirmar que ela está EXPOSTA na fachada do módulo que o caller recebe (não só definida no arquivo interno). Testar gravação em disco no caminho real do store, não chutar o PATH.
**Author:** Claude (claude.ai) — investigação + blocos; Ameno (aplicação + correção da lacuna de fachada `update_model` + validação em disco).
**Validation:** `luac5.4 -p` nos 6 arquivos OK; teste funcional (script Lua isolado) confirmou: `update_model` grava `reasoning_style` no `models.json` real; renomear o modelo ativo sincroniza `active` (sem ref pendurada); baseline restaurado intacto (`active=opencode/hy3-free`, `reasoning_style=reasoning_effort`).
**PR:** Direct commit to main.

---

## 2026-08-22 - [Menu de Thinking Effort (OpenCode Zen) + Clareza de Escopo dos Dois Menus de Effort]
**Contexto:** O menu de Requisições tinha duas configurações de esforço desconectadas: (1) `agents.defaults.request.reasoning_effort` (estilo OpenRouter, 6 níveis) — editável pela opção 7/8; (2) `agents.defaults.thinkingEffort` (estilo `reasoning_effort` / OpenCode Zen, usado pelo payload do Hy3) — até então SÓ editável na mão no config.json. O menu existente (opção 8, "Reasoning Effort", 6 níveis) escrevia em `request.reasoning_effort` e NÃO controlava o `thinkingEffort` que o hy3-free de fato usa — daí a confusão. Investigação do Claude achou que o Hy3 (Tencent) documenta exatamente 3 níveis reais: `no_think` / `low` / `high` — sem `xhigh` (que aparecia em outros modelos do catálogo Zen, mas não no Hy3).
**Files Modified:** `commands/config_cli/menus/request.lua` (monolítico CLI: status mostra as 2 linhas; opção 8 renomeada p/ OpenRouter + nova opção 9 Thinking Effort grava em `agents.defaults.thinkingEffort`); `commands/config/menus/request/{request.lua,view.lua,actions.lua,saver.lua}` (fachada TUI ativa: router ganha opção 9 → `actions.change_thinking_effort`; view mostra as 2 linhas de status; saver ganha `save_defaults` que grava FORA de `request`, direto em `agents.defaults`).
**Learning:** (1) Existem DUAS implementações do menu de Requisições — a monolítica em `config_cli/menus/request.lua` e a fachada em `config/menus/request/` (esta última é a TUI ativa, chamada por `commands/config.lua`). Ao mexer nesse menu, editar AMBAS ou o efeito some numa das duas. (2) `thinkingEffort` vive em `agents.defaults` (irmão de `request`), não dentro de `request` — por isso o `saver.save_req` (que só grava em `request`) não serve; precisa de `save_defaults`. (3) `config.set` grava em `store._data` (memória) E no arquivo, então o status reflete na hora ao reabrir o menu, sem reinício.
**Prevention:** Ao adicionar opção de config que afete modelo, confirmar em QUAL chave ela grava e se essa chave é lida pelo payload correto (`payload.lua` estilo `reasoning_effort` lê `thinkingEffort`, não `request.reasoning_effort`). Não reusar `xhigh` para o Hy3 — só `no_think`/`low`/`high`. Sempre espelhar mudanças de menu entre as duas pastas (`config_cli/menus/` e `config/menus/`).
**Author:** Claude (claude.ai) — investigação + blocos; Ameno (aplicação + descoberta da fachada duplicada + validação).
**Validation:** `luac5.4 -p` nos 5 arquivos OK; teste funcional (script Lua isolado) confirmou que `save_defaults(ctx,"thinkingEffort","no_think")` grava em memória E no config.json, e restaura para `high`; config.json real termina com `thinkingEffort:"high"`.
**PR:** Direct commit to main.

---

## 2026-08-22 - [Causa Raiz: reasoning_style por Provedor (herança de default_reasoning_style)]
**Contexto:** Correção anterior (script pontual em 4 modelos "free") foi curativo, não remédio — todo modelo novo da OpenCode Zen voltaria a nascer sem `reasoning_style`. Investigação achou que `models/resolve.lua` já faz merge com o catálogo curado (campos faltantes do models.json são preenchidos do built-in), mas modelos "contributor/free" (pegos ao vivo via `fetch_remote_models`) não estão no catálogo curado e não têm de onde herdar. O mecanismo de herança já existia, só faltava a camada de provedor.
**Files Modified:** `providers/opencode.lua` (adiciona `default_reasoning_style = "reasoning_effort"`), `providers/openrouter.lua` (adiciona `default_reasoning_style = "openrouter"`), `models/resolve.lua` (nova `find_builtin_provider()` + prioridade `model.reasoning_style` → `provider.default_reasoning_style` → fallback `"openrouter"`).
**Learning:** Config por provedor > config por modelo para atributos que valem para toda a família. Qualquer modelo (curado ou ao vivo) herda o estilo do provedor a menos que sobrescreva. Mudança intencional: modelos CURADOS de reasoning=true no opencode.lua (claude-opus-4-6, claude-sonnet-4-6, gpt-5, gemini-3.1-pro, glm-5.1) também passam a herdar `reasoning_effort` em vez do implícito `openrouter` — correção adicional, não efeito colateral.
**Prevention:** Ao adicionar atributo de modelo que depende de gateway/API, preferir fallback no nível do provedor. O assistente `add_remote.lua` continua só perguntando o booleano `reasoning` — o estilo vem do provedor, não precisa de nova pergunta.
**Author:** Claude (claude.ai) — causa raiz + patch; Ameno (aplicação) — correção + validação.
**Validation:** `luac5.4 -p` nos 3 arquivos OK; Teste1 hy3-free herda `reasoning_effort` sem estar salvo; Teste2 modelo novo free herda `reasoning_effort`; Teste3 gemma openrouter mantém `openrouter` (sem regressão). models.json restaurado ao estado original.
**PR:** Direct commit to main.

---

## 2026-08-22 - [Precisão em ms no Cronômetro do Footer]
**Contexto:** Mesmo após o fix do Bug 1 (ordem de chamada), respostas rápidas de verdade (modelos "free" em 300-700ms) ainda mostravam "0s" porque o footer truncava pra segundos inteiros via `os.time()`. O código já tinha infraestrutura de ms (`timing.get_ms_time()` e `format_duration()`, usados no "Pensou") — faltava estendê-la pro contador total do footer.
**Files Modified:** `ui/spinner/timing.lua` (nova `M.elapsed_total_ms()`, mede desde `_start_ms`), `ui/spinner/compact.lua` (stop_thinking retorna `elapsed_total_ms()` em vez de `elapsed_sec()` nos dois modos), `ui/misc.lua` (require timing + footer usa `format_duration(elapsed_ms)`).
**Learning:** Reusar infraestrutura existente (`get_ms_time`/`format_duration`) em vez de duplicar. `elapsed_total_ms()` mede desde o início do ciclo; não confundir com `elapsed_ms()` (que mede desde o início do reasoning, usado só na linha "Pensou").
**Prevention:** `agent/loop.lua` NÃO precisa mudar — já acumula `elapsed = elapsed + ui.stop_thinking()` cegamente; como stop_thinking agora retorna ms, a soma continua correta (só muda a unidade). `agent/main_loop/overflow_handler.lua` também não precisa mudar — só repassa `elapsed` adiante. Sempre que mudar a unidade de uma métrica, verificar se os consumidores a formatam (footer) ou só a repassam (loop/overflow).
**Author:** Claude (claude.ai) — investigação + patch; Ameno (aplicação) — correção + validação.
**Validation:** `luac5.4 -p` nos 3 arquivos OK; teste funcional `elapsed_total_ms()` retornou 383ms após ~300ms (não 0s); `format_duration` formata "383ms"/"6.8seg"; grep confirma loop.lua e overflow_handler.lua só atribuem/repassam elapsed.
**PR:** Direct commit to main.

---

## 2026-08-22 - [Bug 1 Revisado: Cronômetro "0s" no Footer — Ordem de Chamada no Modo Compact]
**Contexto:** Investigação anterior (2026-08-21) suspeitou que `timing.elapsed_sec()` desse 0 por resolução de 1s do `os.time()`, mas isso não explicava 0s *consistente* em turnos de vários segundos. Causa real (confirmada lendo `ui/spinner/compact.lua` inteiro): no modo thinking `compact` (evidência: mensagens "⬤ Pensou (Xseg)" na tela), `M.stop_thinking()` chamava `M.stop_thinking_and_print_compact()` ANTES de ler `timing.elapsed_sec()`. Como `stop_thinking_and_print_compact()` já invoca `timing.clear_anim()` internamente (zera `_anim_start`), o `elapsed_sec()` lido DEPOIS usava o fallback `_anim_start or os.time()` → `os.time() - os.time()` = 0 **deterministicamente**, não por arredondamento.
**Files Modified:** `ui/spinner/compact.lua` — movido `local elapsed = timing.elapsed_sec()` para ANTES da chamada de `stop_thinking_and_print_compact()` no branch compact.
**Learning:** A investigação anterior (elapsed_sec ter resolução de 1s) estava tecnicamente correta sobre a função, mas NÃO era a causa determinística do sintoma. A causa real era **ordem de chamada** (ler o timer depois de uma função interna já tê-lo zerado). Sempre capturar métricas derivadas de estado mutável ANTES de chamar a função que o limpa. O fix do `agent/loop.lua` (acumular `elapsed`) continua válido e correto, mas residia em nó anterior da cadeia — não consertava este.
**Prevention:** Ao ler estado temporário que será zerado por uma sub-rotina, capture o valor ANTES de invocá-la. Testes de regressão devem forçar turno com tool call no modo compact e confirmar footer ≠ 0s, coerente com o "Pensou (Xseg)".
**Author:** Claude (claude.ai) — causa raiz real; Ameno (aplicação) — correção + validação de sintaxe.
**Validation:** `luac5.4 -p ui/spinner/compact.lua` OK. Teste funcional confirmou que ler DEPOIS do clear retorna 0 determinístico (bug antigo); a ordem corrigida captura antes do clear.
**PR:** Direct commit to main.

---

## 2026-08-21 - [Fix Duplo: Tempo do Footer (Bug 1) + Restart cai pro Shell (Bug 2)]
**Contexto:** Instalação nova (Moto G8 Plus) expôs dois bugs independentes. (1) O footer de tempo mostrava "0s" em turnos com tool call: `agent/loop.lua` sobrescrevia `elapsed` a cada iteração do loop ReAct (`elapsed = ui.stop_thinking()`) em vez de acumular, então só refletia a última perna (curta). (2) O comando `restart` derrubava o TermAI pro shell do Termux em vez de reiniciar: `agent/restart.lua` sai com `os.exit(123)` (contrato com um wrapper externo que relança o processo), mas `install.sh` e o alias manual não tinham esse loop.
**Files Modified:** `agent/loop.lua` (linha 94: `elapsed = elapsed + ui.stop_thinking()`; + comentário na declaração), `install.sh` (wrapper com `while true; do ...; status=$?; if [ "$status" -ne 123 ]; then exit "$status"; fi; done`).
**Learning:** Bug 1 — variáveis de acumulação de tempo em loops ReAct devem somar (`elapsed +`), nunca atribuir (`elapsed =`), senão descartam iterações anteriores. Bug 2 — `os.exit(123)` em `restart.lua` é um contrato implícito com o ambiente externo (wrapper/instalador) para relançar o processo; esse contrato NÃO está documentado em nenhum README e quebrou na instalação fresca.
**Prevention:** (1) Todo acumulador em loop deve usar `+=`-style. (2) QUALQUER wrapper/instalador futuro do TermAI (install.sh, alias, systemd, etc.) DEVE implementar o loop de exit-code 123 — é um contrato entre `agent/restart.lua` e o ambiente externo. Documentar esse contrato no README/install.sh. (3) Após rodar `install.sh` atualizado, remover o `alias TermAI=...` do `~/.bashrc` (alias tem prioridade sobre binário no PATH, senão o wrapper novo fica sem efeito).
**Author:** Claude (claude.ai) — investigação da causa raiz de ambos; Ameno (aplicação) — correção + validação.
**Validation:** `luac5.4 -p agent/loop.lua` OK; `bash -n install.sh` OK; teste unitário do acúmulo (39s = 5+32+2 vs antigo 2s); grep confirma loop de exit 123 no wrapper.
**PR:** Direct commit to main.

---

## 2026-08-21 - [Fix Edit: Falso-Positivo de Sucesso em Falha de Patch]
**Contexto:** A ferramenta Edit exibia "Substituição concluída ✓" em verde mesmo quando o `matcher.lua` rejeitava o patch (ex: trecho ambíguo "aparece mais de uma vez"). O `executor.lua` decide sucesso checando se o resultado começa com `❌` (convenção do projeto), mas `tools/editor.lua` devolvia as mensagens de erro de `edit_engine.replace_multi` sem esse prefixo — então toda falha de Edit era classificada como sucesso pela UI, minando a confiança em qualquer "concluída ✓".
**Files Modified:** `tools/editor.lua` (ambas as ramificações: formato JSON e legado merge-conflict) — adicionado prefixo `"❌ "` no `return` do branch `if not ok`.
**Learning:** `agent/loop/tool_runner/executor.lua` usa `success = not result:match("^❌")` como convenção universal de erro. Qualquer ferramenta que retorne falha sem o prefixo `❌` será interpretada como sucesso. O `parser.is_edit_success` só reverte para `false` se achar `METRICS: added=0, removed=0`, o que não existe em mensagens de erro do matcher — daí o falso-positivo.
**Prevention:** Toda ferramenta do TermAI deve prefixar mensagens de erro com `❌ `. Ao adicionar novas ferramentas ou ramos de retorno de erro, garantir o prefixo; testes de regressão devem forçar patches ambíguos e confirmar "Substituição falha ❌" em vermelho.
**Author:** Claude (claude.ai) — investigação da causa raiz; Ameno (aplicação) — correção + teste funcional do handler real.
**Validation:** `luac5.4 -p tools/editor.lua` OK; teste funcional invocando o handler registrado com `old_text` ambíguo retornou `❌ Falha no patch...` (vermelho); teste de edição válida manteve sucesso intacto.
**PR:** Direct commit to main.

---

## 2026-08-21 - [Fix Streamer: Fechamento Limpo do curl Como Resposta Completa]
**Contexto:** O `streamer.lua` (`pensar_stream`) marcava a resposta como incompleta quando o curl encerrava com código 0 (conexão fechada de forma limpa) sem emitir o sentinela `[DONE]`. Isso gerava falsos cortes de resposta em provedores que não enviam `[DONE]` explícito.
**Files Modified:** `agent/api/request_stream/streamer.lua` (commit `113bb23`).
**Learning:** Em Lua, `h:close()` retorna o código de saída do processo (0 = sucesso/conexão limpa). Um exit 0 do curl indica resposta completa mesmo sem sentinela — só um exit não-zero (ex: 28 = timeout do `--max-time`) indica corte real. O retorno de `h:close()` deve ser capturado (`close_ok`) e combinado com `done_received` para decidir `stream_finished`.
**Prevention:** Ao avaliar término de stream, distinguir fechamento limpo (exit 0) de corte anômalo (exit != 0). Nunca tratar ausência de sentinela como incompletude quando o processo filho saiu com sucesso.
**Author:** Ameno (aplicação) — correção validada por Claude via clone fresco.
**Validation:** `luac5.4 -p` no arquivo + diff conferido por Claude linha a linha.
**PR:** Direct commit to main (SHA: `113bb23`).

---

## 2026-08-20 - [Onboarding de Instalação Fresca: install.sh + Auto-criação de config.json + Mensagem Amigável Sem Modelo]
**Contexto:** Kira reinstalando o TermAI do zero (celular trocado) expôs que a instalação "clone + rodar" documentada no README tinha 3 lacunas: `~/.TermAI/` nunca é criado automaticamente, `config.json` ausente causa `os.exit(1)` cru, e usuário precisava criar alias manual pra ter o comando `TermAI`. Risco real de abandono por usuário novo que roda os comandos do README e não funciona de primeira.
**Files Modified:** `install.sh` (novo), `config/store.lua`, `agent/context.lua`, `models/store.lua` (patch adicional de `mkdir -p`).
**Learning:** `config/migrate.lua` só cria `~/.TermAI/agents/main/agent/` como efeito colateral de migração de config *antigo* — instalação 100% fresca nunca passa por ali, então nenhum diretório nem config padrão é garantido. Mesma classe de bug do `models/store.lua` — `io.open("w")` falha silenciosamente sem diretório pai. **Adição do Ameno:** o `models/store.lua` original (pré-patch) NÃO tinha `mkdir -p`, então `TermAI models add-provider` quebraria na instalação fresca — corrigido com `ensure_dir()` espelhando `config/store.lua`.
**Prevention:** Todo módulo `store.lua` que escreve arquivo dentro de `~/.TermAI/` deve garantir o diretório pai com `mkdir -p` e ter um caminho de "primeira execução" que cria defaults, em vez de assumir que outro fluxo (instalador, migração) já preparou o terreno.
**Author:** Claude (claude.ai) + Ameno (aplicação).
**Validation:** `luac5.4 -p` nos 3 arquivos + teste manual de instalação fresca (apagar ~/.TermAI, rodar install.sh, TermAI tui sem provider, TermAI models add-provider).

---

## 2026-07-30 - [Retry Lines Not Cleared on Tool-Only Responses]

## 2026-07-30 - [Retry Lines Not Cleared on Tool-Only Responses]
**Bug:** When the API returned a response containing only `tool_calls` (no reasoning or content text), the retry status lines (`⚠ Tentativa X/Y`, `⏳ Aguardando Ns...`) were never cleared from the TUI. This happened because `spinner.clear_retry_lines()` was only called inside `ui.stream_reasoning()` and `ui.stream_token()`, which only fire when text deltas arrive. Tool-only responses bypassed both functions.
**Files Modified:**
- `ui/stream.lua` — Created `M.stream_confirm()` (idempotent), removed duplicate guard from `stream_reasoning()` and `stream_token()`
- `agent/api/request_stream/streamer.lua` — Added `ui.stream_confirm()` call on first valid chunk of any type (reasoning, content, or tool_call)
**Learning:** State transitions that depend on "which type of content arrived" create blind spots. The cleanup should happen at the point that knows "something valid arrived", not at the point that knows "what kind of thing arrived".
**Prevention:** Any function that prints ephemeral lines (retry, spinner, warnings) must have a single cleanup entry point called by the streamer on the first valid chunk, regardless of content type. This follows Open/Closed Principle — new delta types don't require new cleanup paths.
**PR:** Direct commit to main (SHA: `251498b`, `1d6da87`)

---

## 2026-07-30 - [Project Architecture Analysis]
**Analysis:** Full codebase review of TermAI (279 Lua files, ~1.6MB).
**Findings:**
- Architecture is coherent: `agent/`, `tools/`, `ui/`, `session/`, `providers/`, `commands/`, `config/` all follow facade+module pattern
- `tools/exec/permissions.lua` (287L) is the #1 candidate for refactoring into `tools/exec/permissions/` folder — exceeds 150L limit, 13 mixed functions
- `todo_write` feature is 100% applied (3 edits confirmed in code)
- Zero orphaned `TODO`/`FIXME`/`XXX` in production code
- Agent swarm (Bolt, Sentinel, Hunter) is operational via Jules API
**Recommendation:** Refactor `permissions.lua` into folder+fachada before it grows further.

---

## 2026-07-30 - [Bash Permissions System — Design Review]
**Context:** PR #12 created by Jules agent implementing bash permissions system.
**Review:** 1042-line diff across 7 files (3 new, 4 modified).
**Findings:**
- Security analysis (`security.lua`): 4 detectors (destructive, path traversal, injection, nested) — functional
- Permission manager (`permissions.lua`): allow/deny rules with wildcards, denial tracking, 3 modes — functional but needs nil guard
- UI dialog (`permissions_ui.lua`): ANSI colors, 4 options + cancel, anti-false-submit — functional
- **Bug Found:** `check("exec", nil)` crashed because `parser.extract_subcommands(nil)` indexed nil. Fixed with nil/empty guard before parser call.
- **Tool Description Updated:** Added bash best practices from OpenClaude (prefer dedicated tools, chain with `&&`, absolute paths, verify parent dir)

---

## 2026-07-31 - [Session Persistence Loses User Message on Total Network Failure]
**Bug:** When all API retry attempts failed on the first call of a turn, `streamer.lua` rolled back the just-appended user message via `table.remove(ctx.msgs)`. Since `main_loop.lua` only persists to the JSONL session file once, at the end of the whole turn, the removed message was never written to disk — lost from memory and from the session file with zero trace. On reopening TermAI, the session reverted to the agent's last message before the user's (now vanished) input.
**Files Modified:**
- `agent/api/request_stream/streamer.lua` — Removed the `table.remove(ctx.msgs)` rollback on total retry failure (kept for the unrelated local-overflow path)
- `session/manager/messages.lua` — `save_message` accepts optional `incomplete` param
- `agent/main_loop/persistence.lua` — `save_exchange` accepts optional `stream_complete` param, flags the last assistant message as incomplete when the stream was cut short
- `agent/main_loop.lua` — passes `stream_complete` through to `save_exchange`
**Learning:** Persistence happening only once, at the end of a potentially multi-iteration turn, turns any in-memory-only rollback inside that turn into permanent silent data loss.
**Prevention:** Rollback (`table.remove`) should only be used for validation failures the caller itself recovers from in the same call stack (e.g. context overflow, which triggers compaction). Never use it as error-cleanup for something the user typed.

## 2026-08-01 - [Compact Thinking Spinner Skips Injetando/Requisitando States]
**Bug:** O script do spinner compacto (`_launch_compact()` em `ui/spinner.lua`) exibia o rótulo "Pensando" fixo desde o primeiro frame, ignorando o parâmetro `label` de `start_thinking()` e nunca checando `_inject_flag`. Resultado: em `thinking_mode = "compact"` a TUI mostrava "Pensando (Xs)" imediatamente — inclusive durante a injeção de memória e a espera do primeiro byte de rede — em vez do fluxo de 3 fases (Injetando → Requisitando → Pensando) que o spinner expandido já implementa corretamente.
**Files Modified:**
- `ui/spinner.lua` — nova constante `_reasoning_flag`; script embutido de `_launch_compact()` agora faz polling de `INJECT_FLAG`/`REASONING_FLAG` pra trocar `LABEL` (Injetando→Requisitando→Pensando), sem alterar o cálculo do timer; `kill_spinner()` limpa também `_reasoning_flag`; `start_thinking()`/`restart_spinner()` escrevem `_inject_flag` igual pros dois modos; `update_label()` deixou de pular o modo compacto; nova `M.mark_reasoning_started()`.
- `ui/stream.lua` — `stream_reasoning()` chama `spinner.mark_reasoning_started()` no primeiro token de reasoning em modo compacto.
**Learning:** Quando um modo de exibição novo é implementado como script paralelo em vez de estender a máquina de estados existente, é fácil reimplementar só o estado final ("Pensando") e perder os estados intermediários que o script original já resolvia via flags.
**Prevention:** Modo de exibição novo pra uma state machine existente deve reusar os mesmos flags/sinais do original, não hardcodar o estado terminal. Confirmar rodando grep pelos rótulos do script original e checando se cada um tem caminho de código alcançável no modo novo.
**Validation:** `luac5.4 -p` nos dois arquivos + teste isolado do script extraído com `sh` (flags criados em intervalos) confirmou a sequência Injetando(0-300ms) → Requisitando(400-600ms) → Pensando(700ms+) com o timer rodando contínuo e sem alteração.

## 2026-08-01 - [Compact Spinner Timer Ran Through Injetando/Requisitando + Missing Blank Line After "Pensou"]
**Bug:** Duas falhas remanescentes no `thinking_mode = "compact"`, na mesma área do fix anterior (ver entrada acima):
1. O `(Xs)` no script embutido de `_launch_compact()` vinha de um contador que rodava desde o lançamento do spinner (fase "Injetando"), aparecendo colado a TODOS os rótulos em vez de nascer só em "Pensando". A entrada anterior corrigiu a troca de rótulos mas deixou o timer intocado de propósito — esse era o gap.
2. `stop_thinking_and_print_compact()` fechava a bolha "⬤ Pensou (Xs)" com um único `"\n"`, grudando a resposta do agente (impressa em seguida via `ui.ai_msg_stream`) verticalmente nela.
**Files Modified:**
- `ui/spinner.lua` — `_launch_compact()` ganhou contador próprio `pc` que só existe/imprime o `(Xs)` quando `REASONING_DONE=1`, zerado na transição; nova var de módulo `_reasoning_start_ms` (setada em `mark_reasoning_started()`, resetada em `start_thinking()`); `stop_thinking_and_print_compact()` calcula `elapsed_ms` a partir dela (fallback pro início do ciclo se não houve reasoning) e fecha com `"\n\n"`.
**Learning:** "Não alterar o timer" foi escopo válido na correção anterior, mas ficou como dívida silenciosa — só ficou visível depois que os rótulos passaram a mudar de verdade.
**Prevention:** Ao corrigir só parte de uma state machine, registrar explicitamente qual parte ficou de fora e por quê, não só o que foi corrigido.
**Validation:** `luac5.4 -p` + teste do script `_launch_compact()` extraído simulando os 3 flags via `touch` em intervalos (~350ms/~750ms): confirmado que o timer só aparece a partir de "Pensando", nascendo em `(0ms)`.

## 2026-08-01 - [Replay Ignorava thinking_mode — Sempre Mostrava Box Expandido]
**Bug/Gap:** `agent/startup/reasoning_renderer.lua` nunca consultava `thinking_mode`. Os 4 call-sites em `agent/startup.lua` chamavam `rr.show_reasoning_box()` direto, então o replay sempre desenhava a caixa "Pensamento Concluído ✓" (estilo expandido), mesmo com `thinking_mode = "compact"` ativo, e independente do modo que estava ativo quando a mensagem foi gerada. Não existia variante compacta pro replay.
**Decisão (Samuel):** replay dinâmico — reflete sempre o `thinking_mode` ATUAL da config pro histórico inteiro (não persiste o modo por mensagem no JSONL).
**Files Modified:**
- `agent/startup/reasoning_renderer.lua` — nova `show_reasoning_compact()` (bolha "⬤ Pensamento", sem duração — elapsed não é persistido) e novo dispatcher público `M.show_reasoning(reasoning)` que lê `thinking_mode` e escolhe entre `show_reasoning_box` (existente, intocada) e `show_reasoning_compact`.
- `agent/startup.lua` — as 4 chamadas trocaram de `rr.show_reasoning_box(` pra `rr.show_reasoning(`.
**Learning:** Uma função "pura" que renderiza uma coisa só tende a virar ponto cego quando o produto ganha um segundo modo de exibição em outro lugar do sistema (o spinner) — ninguém "esqueceu" o replay, ele só nunca foi conectado ao novo conceito de `thinking_mode` quando ele nasceu.
**Prevention:** Toda vez que uma config nova tipo `thinking_mode` for introduzida, dar `grep -rn` por TODOS os pontos que renderizam o conceito que ela afeta (aqui: reasoning/thinking em qualquer lugar da TUI), não só o caminho ao vivo — replay/histórico é code path separado e fácil de esquecer.
**Validation:** `luac5.4 -p` nos dois arquivos.

## 2026-08-02 - [Memory Flush Sem Spinner Visual na TUI]
**Bug/Contexto:** `agent/flush.lua` (FlushLoop) chama `api.pensar_stream` diretamente em loop headless, sem nunca chamar `ui.start_thinking`/`ui.update_label`/`ui.stop_thinking`. O streamer (`agent/api/request_stream/streamer.lua`) já dispara `ui.stream_start/stream_confirm/stream_reasoning/stream_token/stream_end` incondicionalmente para QUALQUER chamador — inclusive o flush — mas como nenhum spinner script foi lançado (`ui.start_thinking` nunca chamado), essas chamadas não tinham efeito visual: nada aparecia na TUI durante o Memory Flush.
**Files Modified:**
- `agent/flush.lua` — adiciona `require("ui")`; `ui.start_thinking("Injetando")` no início de `M.run` (cobre a montagem do contexto isolado, análogo à injeção de memória do loop normal); `ui.update_label()` antes do while (transição Injetando→Requisitando); flag `spinner_started` replicando o padrão de `agent/loop.lua` pra não reiniciar o spinner na primeira iteração; `ui.stop_thinking()` logo após cada `api.pensar_stream`, antes de checar overflow/tool_calls (mesma ordem de `agent/loop.lua`).
**Learning:** O pipeline de streaming (`ui.stream_*`) já era genérico e chamado por qualquer consumidor de `api.pensar_stream` — o gap não estava no streaming, estava em nunca ter iniciado o *spinner* (`ui.start_thinking`), que é quem o streaming pilota via flag-files. Reaproveitar 100% do facade existente (zero lógica nova, zero "modo" separado pro flush) resolveu o problema.
**Prevention:** Ao criar um novo consumidor headless de `api.pensar_stream`, sempre espelhar o par `ui.start_thinking(...)` / `ui.stop_thinking()` ao redor da chamada — o streamer assume que alguém já "acendeu" o spinner antes do primeiro byte chegar.
**Validation:** `luac5.4 -p agent/flush.lua` + confirmação visual: disparar um flush manualmente em `thinking_mode=compact` (deve ver Injetando→Requisitando→Pensando) e em `thinking_mode=expanded` (deve ver o box normal).

## 2026-08-02 - [Falso "Resposta Incompleta" em Falha Total de Rede + Logs de Erro de API Pobres]
**Bug/Contexto:** Dois problemas relacionados detectados após um retry storm de `[400] Provider returned error` (5 tentativas, mesma mensagem genérica de gateway):
1. `agent/api/request_stream/streamer.lua`, no `return` final após esgotar todas as tentativas, retornava `done_flag = false` (3º valor) — o MESMO valor usado pra sinalizar "stream começou mas foi cortado antes do [DONE]". `agent/main_loop.lua` não distingue os dois casos e sempre mostra "⚠️ Resposta incompleta — o stream foi cortado", mesmo quando NENHUM byte de resposta foi recebido (falha total de rede/provider).
2. O corpo bruto da resposta de erro do provider era descartado — só `.error.message` (string genérica, ex.: gateway embrulhando o erro real do provider downstream) era guardado, sem log em disco. Uma vez que o terminal rola, a causa raiz real (status HTTP, corpo completo, type/code do erro) se perde pra sempre.
**Files Modified:**
- `agent/api/request_stream/streamer.lua` — return final de falha total agora usa `done_flag = nil` (não `false`); usa `error_log.describe()` em vez de só `.message`; chama `error_log.record()` antes de cada retry/desistência.
- `agent/api/request_stream/error_log.lua` (NOVO) — `M.describe(err)` extrai type/code/param além de `.message`; `M.record(...)` persiste tentativa+endpoint+corpo bruto (truncado a 4000 chars) em `$TMPDIR/termai_api_errors.log`, com teto de 200KB (auto-descarta se passar).
**Learning:** Um valor booleano reaproveitado pra dois significados diferentes ("stream cortado" vs "não aplicável/sem stream") é uma armadilha clássica — o caller não tem como diferenciar sem um terceiro estado. E: sem persistir o corpo bruto de erro em disco, diagnóstico de erro de API vira "reproduzir e torcer" — a mensagem resumida na tela nunca é suficiente quando o erro vem de um gateway que embrulha o erro real do provider.
**Prevention:** Retornos booleanos que alimentam mensagens de UI precisam de um terceiro estado explícito (nil/enum) pra "não aplicável", nunca reaproveitar `false`. Todo erro de rede exibido de forma resumida deve ter o corpo bruto correspondente indo pra um log em disco — a UI é efêmera, o log não.
## 2026-08-03 - [Banner do Memory Flush: Largura Fixa Não Acompanhava o Terminal + Título Não Centralizado]
**Bug/Contexto:** `agent/banners.lua` usava `string.rep("━", 50)` hardcoded pras linhas do banner (Memory Flush e Compactação), enquanto todo o resto do projeto já usa `core.tw()` pra descobrir a largura real do terminal via `stty size`. Em telas mais largas que 50 colunas, a linha amarela parava no meio. Título também tinha só um espaço fixo, nunca centralizado.
**Files Modified:**
- `agent/banners.lua` — `M.flush`: linha usa `core.tw()`; título centralizado via `core.wlen()` + padding; removidos 🧠 e 📨 (pedido do Samuel, escopo restrito a esse banner). `M.compactacao`: só a largura corrigida (mesmo bug), título/emoji mantidos — Samuel não pediu mudança lá.
**Learning:** `banners.lua` era o único arquivo do projeto ainda com largura hardcoded — todo o resto já convergiu pra `core.tw()`. Números mágicos sobrevivem em arquivos raramente tocados (banner é escrito uma vez e esquecido).
**Prevention:** Ao adicionar qualquer linha/borda decorativa nova no TUI, `grep -rn "core.tw()"` primeiro pra confirmar que não está reinventando a largura na mão.
**Nota (decisão pendente):** ❌/✅/📊 nos resultados de exec/Read/Write NÃO são exclusivos do Memory Flush — estão em ~25 arquivos de `tools/` e são parte do texto que o próprio modelo lê como resultado da tool call, não só decoração de UI. O "🔴" visto nos logs é o mesmo "⬤" colorido do spinner (`ui/tools_init/header.lua`), reaproveitado como status (amarelo/verde/vermelho) — não é emoji solto. Nenhuma mudança feita aqui; aguardando decisão do Samuel.
**Validation:** `luac5.4 -p agent/banners.lua` + inspeção visual do próximo flush disparado.

## 2026-08-04 - [Spinner Orphan Process Bug: restart_spinner() Não Rearmava Guard de Animação]
**Bug/Contexto:** Em modo `compact`, quando uma tentativa de API falhava, `streamer.lua` chamava `ui.stream_end()` mesmo sem dados — isso disparava `stop_thinking_and_print_compact()`, que zerava `_anim_start`. A função `restart_spinner()` (chamada logo depois pra relançar o spinner na próxima tentativa) **nunca re-armava** essa variável. Resultado: quando a 2ª tentativa dava certo, `stop_thinking_and_print_compact()` via `_anim_start == nil` e retornava imediatamente — o processo `sh` do spinner relançado **nunca era morto** e ficava escrevendo por cima da resposta em stream (o "loop preso" na tela). Só afetava modo `compact` (reproduziu com Minimax M3 sem reasoning).
**Files Modified:**
- `ui/spinner.lua` — `M.restart_spinner()`: adicionadas linhas `_anim_start = os.time()` e `_start_ms = get_ms_time()` antes de relançar o processo sh, garantindo que o guard de animação esteja armado para a nova tentativa.
**Learning:** Quando uma função "re-inicia" um estado (spinner, timer, flag), ela precisa re-armar **todos** os guards que outras funções usam pra decidir se agem. O `restart_spinner()` relançava o processo sh mas esquecia que `_anim_start` era o guard que `stop_thinking_and_print_compact()` usava pra decidir se limpava o spinner.
**Prevention:** Toda função que relança um componente com guard (flag, variável de estado) deve re-armar todos os guards relevantes. Verificar com `grep` quais funções leem o guard antes de modificar o componente.
**Author:** Claude Sonnet 5
**Validation:** `luac -p ui/spinner.lua`

## 2026-08-04 - [Canal Telegram — Poller, Streaming via Edição e Aprovação via Chat]
**Contexto:** Novo domínio `channels/`, paralelo a `ui/`. Objetivo: operar o TermAI remotamente via Telegram (Termux headless), reusando 100% do núcleo (`agent.loop.rodar`, `agent/main_loop/*`, `session/store`) sem duplicar lógica.
**Descoberta chave:** `startup.run(ctx)` não é só visual — carrega `ctx.msgs`/tokens da sessão. O entry point do Telegram chama normalmente; o ruído ANSI num processo sem TTY é inofensivo.
**Bloqueio identificado:** `tools/exec/permissions_ui.lua` e `agent/hooks/bash_patterns/ui.lua` usam `io.read` bloqueante — travaria para sempre num processo sem TTY. Resolvido com um backend plugável (`agent/hooks/approval_backend.lua`) registrado só quando o canal Telegram está ativo; comportamento de terminal inalterado por padrão.
**Streaming:** em vez de tocar em `agent/api/request_stream/streamer.lua` (arquivo sensível), `ui/stream.lua` ganhou um sink plugável (`M.set_sink`) — o streamer continua chamando `ui.stream_token`/`ui.stream_reasoning` normalmente, sem saber que existe um canal alternativo.
**Arquivos criados:** `agent/hooks/approval_backend.lua`, `channels/telegram.lua`, `channels/telegram/{api,offset_store,allow_from,stream_sink,approval,bridge}.lua`, `agente_telegram.lua`.
**Arquivos modificados (gancho mínimo, comportamento padrão inalterado):** `tools/exec/permissions_ui.lua`, `agent/hooks/bash_patterns/ui.lua`, `ui/stream.lua`.
**Fora do escopo desta v1:** comandos de terminal via chat, botões inline, `/restart` via Telegram, silenciar spinner em modo headless.
**Author:** Claude (claude.ai)
**Validation:** `luac -p` nos 12 arquivos

## 2026-08-04 - [Tool "exec" Renomeada para "Exec" + Filtro de Providers Web na Lista de Modelos]
**Contexto:** Duas correções. (1) TUI mostrava a tool de shell como "exec" minúsculo, inconsistente com Read/Write/Edit/Grep/List/Find. (2) Catálogo de "Provedor built-in" listava providers de busca web (duckduckgo_search, tavily_search, google_grounding) que não têm `.models`.
**Files Modified:** tools/exec.lua, tools/exec/permissions_ui.lua, tools/exec/permissions.lua, tools/exec/executor.lua, agent/hooks/engine.lua, agent/hooks/bash_patterns/ui.lua, channels/telegram/approval.lua, agent/startup.lua, agent/flush.lua, memoryflush/prompt.lua, prompt.lua, tools/error_feedback/feedback.lua, commands/available.lua, agent/tools_handler/executor.lua, providers/init.lua, commands/models/providers/add.lua.
**Learning:** Rename de tool não é cosmético quando o nome é chave de comparação em lógica de segurança. `grep -rn "exec"` achou 14 arquivos.
**Author:** Claude Sonnet 5 + Ameno
**Validation:** `luac -p` nos 16 arquivos + grep zero-"exec"

---

## 2026-08-05 - [Permissão Exec: Subcomando Fantasma "(", Overflow na TUI, Caixa Presa no Live e Texto do Agente Confundido com Comando]
**Bug/Contexto:** Quatro falhas relacionadas no fluxo de permissão do Exec, achadas investigando um caso real onde apareceu "Subcomando pendente: (" num script multi-linha:
1. `parser.extract_subcommands` tratava `\n` como separador idêntico a `;`, sem rastrear profundidade de parênteses — um subshell `(\n cmd\n)` vazava `"("`/`")"` como "subcomandos" próprios.
2. `permissions_ui.lua` truncava `display_cmd` em 150 chars mas nunca truncava `failed_sub` — fragmento grande estourava a TUI.
3. O diálogo escreve ANSI cru via `io.write`/`io.read`, fora do modelo de mensagens/sessão — nunca é persistido (por isso some no replay) e ao vivo fica preso no scrollback até reiniciar (nada nunca limpa aquela região).
4. Texto solto do agente sem aspas (ex: "Vou trazer os arquivos...") é sintaticamente válido pro parser e virava "subcomando" pendente como se fosse ação real.
**Files Modified:**
- `agent/hooks/bash_patterns/parser.lua` — nova `is_real_subcommand(s)` (exige ≥1 char alfanumérico), aplicada nas 3 capturas.
- `tools/exec/permissions.lua` — nova `M.command_exists(name)` (via `command -v` no mesmo `sh` do executor real, `shell_quote` anti-injeção); `check()` retorna `unknown_cmd` no reason "ask" — puramente informativo, não bypassa decisão.
- `tools/exec/permissions_ui.lua` — `display_text()` unificado trunca comando e subcomando; `show_dialog` conta linhas (`wl()`) e colapsa a caixa via `\27[1A\27[K` (idioma já usado em `ui/stream.lua`) numa linha de status resolvida; nova linha de aviso pra `unknown_cmd`.
- `agent/hooks/engine.lua` — propaga `check.unknown_cmd`.
**Learning:** Bugs 1 e 4 tinham a mesma causa raiz — parser nunca validava a FORMA do fragmento extraído, só se não era vazio. UI com `io.write` cru fora do pipeline de sessão sempre diverge entre live e replay.
**Prevention:** Parser de "unidades executáveis" precisa validar forma, não só não-vazio. UI fora do `ui.*` module precisa tratar seu próprio ciclo de vida (aparecer→resolver→colapsar), não depender de restart.
**Validation:** `luac -p` nos 4 arquivos + `tests/bash_patterns_bug.lua` (64/64, zero regressão) + 3 testes de falsificação direcionados.
**Author:** Claude Sonnet 5 + Ameno (aplicação + auditoria)
**Debt Nota:** `parser.lua` já estava com 210 linhas antes deste patch — acima do limite de 150. Fica registrado como dívida técnica pra refactor futuro em `bash_patterns/parser/`.

---

## 2026-08-05 - [Cache em Disco do Grafo de Memória + Otimização de lower()]
**Contexto:** Todo boot/restart reconstruía o grafo de memória do zero — lendo e reprocessando (regex de tags + snippet por tag + arestas) todo o histórico de memória. Com 80+ arquivos .md, isso causava lentidão perceptível no "Injetando" inicial.
**Causa Raiz:** `tools/memory.lua` só tinha cache em RAM (`_cache.graph`) — não sobrevivia a restarts. Além disso, `get_snippet()` fazia `content:lower()` do arquivo inteiro **por tag** (redundante: 10 tags = 10 lower() do mesmo texto).
**Files Modified:**
- `tools/memory/graph_cache.lua` (NOVO) — Persistência em disco do cache (`.graph_cache.json`). `load()` retorna nil em qualquer falha (nunca derruba boot). `save()` é melhor-esforço.
- `tools/memory/graph_builder.lua` — `parse_file()` aceita `cached_entry` e reutiliza tags/snippets se `size` em bytes não mudou. `build_graph()` retorna `entries_out` para persistir.
- `tools/memory/tag_parser.lua` — `get_snippet()` aceita `lower_content` opcional (pré-computado pelo caller).
- `tools/memory.lua` — Integra `graph_cache` no `get_graph()`: load → build com cache → save.
**Learning:** Otimização de cache em disco é segura quando a chave (tamanho em bytes) é um proxy confiável para "conteúdo inalterado" — verdade para arquivos de memória datados que crescem monotonicamente.
**Performance:** ~2-2.6x mais rápido no boot com cache quente. `lower()` agora é 1x por arquivo em vez de N (N = nº de tags).
**Validation:** `luac -p` nos 4 arquivos + sync GitHub commit `9cf95c7`.
**Author:** Claude Sonnet 5 + Ameno (aplicação + auditoria)
