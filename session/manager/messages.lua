-- messages.lua — Gravação de mensagens e registros de compactação.
-- v2: aceita tool_calls/tool_call_id opcionais. Sem isso, history.lua não
-- tem como restaurar role="tool" e assistant+tool_calls depois de restart.
-- v3: save_compaction aceita 'details' opcional (REQ-5: file tracking
-- cumulativo — read/created/edited files) e expõe get_last_compaction
-- (REQ-3: permite ao próximo do_compaction ler o resumo anterior pra
-- merge iterativo, em vez de resumir do zero a cada compactação).
local state       = require("session.manager.state")
local date_utils   = require("session.manager.date_utils")
local session_ops = require("session.manager.session_ops")
local generate     = require("session.generate")
local store        = require("session.store")
local M = {}

local function save_message(role, content, tokens, skip_counters, reasoning, tool_calls, tool_call_id, pasted_texts)
  local entry = {
    id        = generate.entry_id(),
    role      = role,
    content   = content,
    tokens    = tokens or 0,
    timestamp = date_utils.now_iso(),
  }
  if pasted_texts and type(pasted_texts) == "table" then
    entry.pasted_texts = pasted_texts
  end
  if role == "assistant" and reasoning and reasoning ~= "" then
    entry.reasoning = reasoning
  end
  -- v2: só grava se vier válido e completo — nunca campo pela metade.
  if role == "assistant" and tool_calls and type(tool_calls) == "table" and #tool_calls > 0 then
    entry.tool_calls = tool_calls
  end
  if role == "tool" and tool_call_id and tool_call_id ~= "" then
    entry.tool_call_id = tool_call_id
  end
  store.append_message(state._current, entry)
  if not skip_counters then
    local s = session_ops.find_session(state._current)
    if s then
      s.msg_count = (s.msg_count or 0) + 1
      if tokens and tokens > 0 then
        s.total_tokens = tokens  -- rastreia último contexto conhecido (não soma cumulativa)
      end
      s.updated_at    = date_utils.now_iso()
      s.last_activity = date_utils.now_iso()
    end
    store.save_index(state._index)
  end
end

local function save_compaction(summary, tokens_before, recent_msgs, details)
  local s = session_ops.find_session(state._current)
  local key = s and s.key or "default"
  -- v3: sobrescrita atômica pós-compactação — purga lixo do disco
  if recent_msgs and #recent_msgs > 0 then
    store.rewrite_compacted_session(state._current, key, summary, tokens_before, recent_msgs, details)
  else
    -- fallback legado: se recent_msgs não foi fornecido, append normal
    local entry = {
      type          = "compaction",
      id            = generate.entry_id(),
      summary       = summary or "Contexto anterior compactado.",
      tokens_before = tokens_before or 0,
      timestamp     = date_utils.now_iso(),
    }
    if details then entry.details = details end
    store.append_entry(state._current, entry)
  end
  if s then
    s.compaction_count = (s.compaction_count or 0) + 1
    s.updated_at       = date_utils.now_iso()
    s.last_activity    = date_utils.now_iso()
  end
  store.save_index(state._index)
end

-- REQ-3: retorna (summary, details) da última compactação persistida
-- desta sessão, ou (nil, nil) se nunca houve uma. Usado por do_compaction
-- pra fundir com o resumo anterior em vez de resumir do zero.
-- Nota: rewrite_compacted_session reescreve o arquivo inteiro a cada
-- compactação (só sobra 1 entry type=compaction por vez no disco), então
-- não é preciso desambiguar entre múltiplas — mas o scan de trás pra
-- frente é mantido por segurança/robustez.
local function get_last_compaction(session_id)
  session_id = session_id or state._current
  local entries = store.read_active_entries(session_id)
  for i = #entries, 1, -1 do
    if entries[i].type == "compaction" then
      return entries[i].summary, entries[i].details
    end
  end
  return nil, nil
end

M.save_message         = save_message
M.save_compaction      = save_compaction
M.get_last_compaction  = get_last_compaction
return M
