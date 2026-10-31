-- persistence.lua — Persistência de mensagens no JSONL e guarda de flush ativo.
-- v2–v5: tool_calls, tokens meta, fresh, pasted_texts.
-- v6 #279: adjust_before localiza user deslocado por recover.
local session = require("session")
local M = {}

--- Se recover removeu órfãos com índice <= msgs_before, o user desloca.
--- Localiza pela referência de conteúdo stampado do turno.
function M.adjust_before(ctx, msgs_before, stamped)
  local n = #ctx.msgs
  local i0 = msgs_before + 1
  if i0 <= n and ctx.msgs[i0] and ctx.msgs[i0].role == "user" then
    return msgs_before
  end
  if not stamped then return msgs_before end
  for i = n, 1, -1 do
    local m = ctx.msgs[i]
    if m.role == "user" and m.content == stamped then
      return i - 1
    end
  end
  return msgs_before
end

local function save_exchange(ctx, msgs_before, reasoning, original_input, fresh, pasted_texts, stream_complete)
  local total = #ctx.msgs
  for i = msgs_before + 1, total do
    local m = ctx.msgs[i]
    if m and m.role and m.content then
      local is_first = (i == msgs_before + 1)
      local is_last  = (i == total)
      local tok      = is_last and ctx.tokens or 0
      local skip     = not (is_first or is_last)
      local r        = m.reasoning or ((is_last and m.role == "assistant") and reasoning or nil)
      local content  = (is_first and m.role == "user" and original_input) or m.content
      local p_texts  = (is_first and m.role == "user") and pasted_texts or nil
      local incomplete = is_last and m.role == "assistant" and stream_complete == false
      session.save_message(m.role, content, tok, skip, r, m.tool_calls, m.tool_call_id, p_texts, incomplete)
    end
  end
  if fresh == nil then fresh = true end
  session.save_session_tokens(ctx.tokens, fresh)
end

local function flush_ativo(ctx)
  return ctx.compaction.flush_tokens
     and ctx.compaction.flush_enabled ~= false
end

M.save_exchange = save_exchange
M.flush_ativo   = flush_ativo
return M
