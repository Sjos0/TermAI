-- history.lua — Leitura e formatação do histórico de mensagens.
-- v3: CORRIGE regressão da v2. role="tool" só é carregado com tool_call_id
-- válido presente — sem isso a API rejeita o payload inteiro (foi o que
-- quebrou o provider em loop). Hoje messages.lua/save_message não salva
-- esse campo, então o efeito é idêntico ao pré-v2 — mas pronto para quando
-- o lado de gravação (persistence.lua) foi atualizado.
-- v4: Usa o carregador otimizado read_active_entries para acelerar inicialização.
-- v5: Propaga pasted_texts para a TUI do Replay.
local state      = require("session.manager.state")
local date_utils = require("session.manager.date_utils")
local store      = require("session.store")
local M = {}

local function make_content(e)
  if e.role == "assistant" or e.role == "tool" then return e.content or "" end
  local content = e.content or ""
  if content:match("^%[%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%]") then
    return content
  end
  local ts     = date_utils.iso_to_timestamp(e.timestamp)
  local prefix = ts and ("[" .. ts .. "] ") or ""
  return prefix .. content
end

local function build_msg(e)
  local msg = { role = e.role, content = make_content(e) }
  if e.role == "assistant" and e.reasoning and e.reasoning ~= "" then
    msg._reasoning = e.reasoning
  end
  -- Propaga os metadados dos pasted_texts para a TUI do Replay
  if e.pasted_texts then
    msg.pasted_texts = e.pasted_texts
  end
  -- Só anexa se vier completo — nunca metade do par tool_calls/tool_call_id.
  if e.tool_calls and type(e.tool_calls) == "table" and #e.tool_calls > 0 then
    msg.tool_calls = e.tool_calls
  end
  if e.tool_call_id and e.tool_call_id ~= "" then
    msg.tool_call_id = e.tool_call_id
  end
  return msg
end

-- v3 fix: role="tool" exige tool_call_id válido. Protocolo OpenAI obriga
-- que toda mensagem "tool" referencie um tool_calls[].id da mensagem
-- assistant anterior — sem isso o provider rejeita o payload inteiro.
local function is_loadable(e)
  if e.type ~= "message" then return false end
  if e.role == "user" or e.role == "assistant" then return true end
  if e.role == "tool" then return e.tool_call_id ~= nil and e.tool_call_id ~= "" end
  return false
end

local function load_history()
  -- Otimização crítica: lê apenas as entradas de histórico ativas
  local entries = store.read_active_entries(state._current)
  if #entries == 0 then
    local r = {}
    r._last_tokens = 0
    return r
  end

  local last_tok = 0
  for i = #entries, 1, -1 do
    if entries[i].tokens and entries[i].tokens > 0 then
      last_tok = entries[i].tokens
      break
    end
  end

  local is_new = (entries[1].type == "session")
  local result = {}

  if is_new then
    local last_comp = nil
    for i, e in ipairs(entries) do
      if e.type == "compaction" then last_comp = i end
    end
    if last_comp then
      local comp = entries[last_comp]
      result[#result + 1] = {
        role        = "user",
        content     = "[Resumo do contexto anterior — conversa compactada]\n\n"
                    .. (comp.summary or "Contexto anterior resumido."),
        _compaction = true,
      }
      result[#result + 1] = {
        role        = "assistant",
        content     = "Entendido. Tenho o contexto resumido. Continuando.",
        _compaction = true,
      }
      for i = last_comp + 1, #entries do
        local e = entries[i]
        if is_loadable(e) then result[#result + 1] = build_msg(e) end
      end
    else
      for _, e in ipairs(entries) do
        if is_loadable(e) then result[#result + 1] = build_msg(e) end
      end
    end
  else
    for _, e in ipairs(entries) do
      if e.role == "user" or e.role == "assistant"
         or (e.role == "tool" and e.tool_call_id and e.tool_call_id ~= "") then
        result[#result + 1] = build_msg(e)
      end
    end
  end

  result._last_tokens = last_tok
  return result
end

M.load_history = load_history
return M
