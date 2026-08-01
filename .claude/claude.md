# Claude — Contribution Log

Registro de contribuições do Claude (claude.ai) ao projeto TermAI.

---

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
**Note:** True per-sub-turn incremental persistence (saving after every API call inside the ReAct loop, not just once at the end) was proposed as a separate follow-up, not implemented in this pass.
**Test Coverage:** 71 tests (36 original + 35 extended) — 100% passing
**Files Modified:**
- `tools/exec/permissions.lua` — Added nil/empty check (bug fix)
- `tools/exec.lua` — Updated tool description with bash best practices
- `tests/exec_permissions_extended.lua` — Created 35 additional tests
