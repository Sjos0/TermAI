-- session/store/writer.lua — Subsistema de persistência ativa e gravação JSONL.
-- v2: rewrite_compacted_session aceita 'details' opcional (REQ-5: file
-- tracking cumulativo) — gravado na entry type=compaction quando presente.
local json = require("json")
local common = require("session.store.common")
local M = {}

-- Resolução dinâmica tardia para evitar referências circulares em runtime
local function get_index_mod()
  return require("session.store.index")
end

-- ── JSONL: append de entrada tipada ─────────────────────────────────────────
function M.append_entry(session_id, entry)
  local path = common.jsonl_path(session_id)
  local f = io.open(path, "a")
  if not f then return false end
  f:write(json.encode(entry) .. "\n")
  f:close()
  return true
end

-- ── Header da sessão (auto-migra transcripts antigos) ───────────────────────
function M.write_header(session_id, key)
  local path = common.jsonl_path(session_id)
  local f = io.open(path, "r")
  if f then
    local first = f:read("*l")
    f:close()
    if first and first ~= "" then
      local ok, entry = pcall(json.decode, first)
      if ok and entry and entry.type == "session" then
        return false
      end
      local all = io.open(path, "r")
      if all then
        local content = all:read("*a"); all:close()
        local header = json.encode({
          type      = "session",
          version   = 1,
          id        = session_id,
          key       = key,
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }) .. "\n"
        local out = io.open(path, "w")
        if out then
          out:write(header .. content)
          out:close()
        end
        return true
      end
    end
  end
  return M.append_entry(session_id, {
    type      = "session",
    version   = 1,
    id        = session_id,
    key       = key,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  })
end

-- ── Compatibilidade: append_message ─────────────────────────────────────────
function M.append_message(session_id, msg)
  if not msg.type then msg.type = "message" end
  return M.append_entry(session_id, msg)
end

function M.delete_file(session_id)
  os.remove(common.jsonl_path(session_id))
end

function M.list_transcript_files()
  get_index_mod().ensure_dir()
  local files = {}
  local handle = io.popen('ls "' .. common.SESSIONS_DIR .. '" 2>/dev/null')
  if handle then
    for entry in handle:lines() do
      if entry:match("%.jsonl$") and not entry:match("checkpoint") then
        files[#files + 1] = entry:match("^(.+)%.jsonl$")
      end
    end
    handle:close()
  end
  return files
end

-- ── Sobrescrita atômica pós-compactação (POSIX rename) ─────────────────────
-- Purga todo o lixo obsoleto do disco: preserva apenas cabeçalho,
-- entrada de compactação e mensagens sobreviventes.
function M.rewrite_compacted_session(session_id, key, summary, tokens_before, recent_msgs, details)
  if not recent_msgs or #recent_msgs == 0 then return false end
  if not get_index_mod().ensure_dir() then return false end
  local target_path = common.jsonl_path(session_id)
  local tmp_file = target_path .. ".tmp"
  local f = io.open(tmp_file, "w")
  if not f then return false end
  -- 1. Cabeçalho da sessão
  f:write(json.encode({
    type      = "session",
    version   = 1,
    id        = session_id,
    key       = key,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }) .. "\n")
  -- 2. Entrada de compactação (resumo do Estado Condensado)
  local comp_entry = {
    type          = "compaction",
    id            = "comp_" .. os.time(),
    summary       = summary or "Contexto anterior compactado.",
    tokens_before = tokens_before or 0,
    timestamp     = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  if details then comp_entry.details = details end
  f:write(json.encode(comp_entry) .. "\n")
  -- 3. Mensagens sobreviventes (pula índice 1 = system prompt)
  for i = 2, #recent_msgs do
    local m = recent_msgs[i]
    if m then
      local entry = {
        type         = "message",
        id           = m.id or ("msg_" .. os.time() .. "_" .. i),
        role         = m.role,
        content      = m.content,
        tokens       = m.tokens or 0,
        timestamp    = m.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ"),
        tool_calls   = m.tool_calls,
        tool_call_id = m.tool_call_id,
        reasoning    = m.reasoning,
      }
      if m.pasted_texts then entry.pasted_texts = m.pasted_texts end
      f:write(json.encode(entry) .. "\n")
    end
  end
  f:close()
  -- Substituição atômica via Rename POSIX
  local ok = os.rename(tmp_file, target_path)
  if not ok then
    os.remove(tmp_file)
    return false
  end
  return true
end

return M
