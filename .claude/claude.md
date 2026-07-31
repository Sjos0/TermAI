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
**Test Coverage:** 71 tests (36 original + 35 extended) — 100% passing
**Files Modified:**
- `tools/exec/permissions.lua` — Added nil/empty check (bug fix)
- `tools/exec.lua` — Updated tool description with bash best practices
- `tests/exec_permissions_extended.lua` — Created 35 additional tests
