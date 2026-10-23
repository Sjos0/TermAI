-- tools/subagents/snapshot.lua — Salva o último texto útil do filho enquanto ele roda (issue #93).
-- Assim um timeout ou uma morte não descarta o trabalho. Já sai redigido; grava no máximo a cada
-- 10 s e só quando o texto mudou, para não gastar I/O no celular.
local registry = require("tools.subagents.registry")
local redact   = require("tools.subagents.redact")

local M = {}
local MIN_INTERVAL = 10
local last = {}   -- runId -> { text = ..., at = ... }

local function last_assistant(msgs)
  for i = #msgs, 1, -1 do
    local m = msgs[i]
    if m and m.role == "assistant" and type(m.content) == "string" and m.content ~= "" then
      return m.content
    end
  end
  return nil
end

-- Devolve true se gravou um snapshot nesta chamada.
function M.tick(ctx, now)
  now = now or os.time()
  if not (ctx and ctx.is_subagent and ctx.run_id) then return false end
  local text = last_assistant(ctx.msgs or {})
  if not text then return false end
  local prev = last[ctx.run_id]
  if prev and prev.text == text then return false end
  if prev and now - prev.at < MIN_INTERVAL then return false end
  registry.write_partial(ctx.run_id, redact.clean(text))
  last[ctx.run_id] = { text = text, at = now }
  return true
end

return M
