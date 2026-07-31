-- persistence.lua — Persistência de mensagens no JSONL e guarda de flush ativo.
-- v2: propaga tool_calls/tool_call_id de cada mensagem ao salvar — completa
-- o par com messages.lua v2 para restaurar o contexto nativo após restart.
-- v3: persiste ctx.tokens em registro meta dedicado (Bug C fix).
-- v4: save_exchange aceita param 'fresh' pra flag tokens_fresh (TFA-001-R3/R4).
-- v5: aceita param 'pasted_texts' pra metadados de textos colados.
local session = require("session")
local M = {}

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
  -- v4: persiste ctx.tokens com flag fresh em registro meta dedicado.
  if fresh == nil then fresh = true end  -- default: confiável (compat retroativa)
  session.save_session_tokens(ctx.tokens, fresh)
end

local function flush_ativo(ctx)
  return ctx.compaction.flush_tokens
     and ctx.compaction.flush_enabled ~= false
end

M.save_exchange = save_exchange
M.flush_ativo   = flush_ativo
return M
