-- orphan_scan.lua — Recuperação automática de sessões órfãs no boot.
-- Uma sessão órfã é um arquivo .jsonl presente no SESSIONS_DIR que não tem
-- entrada correspondente no índice (sessions.json). Ocorre quando backups
-- são restaurados sem o índice, ou quando o índice é regenerado do zero.
-- O scan extrai metadados (msg_count, tokens, timestamps) do próprio
-- conteúdo do arquivo e registra a sessão no índice em memória + disco.
local state  = require("session.manager.state")
local store  = require("session.store")
local json   = require("json")
local common = require("session.store.common")
local M = {}

-- ── Extração de metadados direto do JSONL ───────────────────────────────────
local function extract_meta(session_id)
  local path = common.jsonl_path(session_id)
  local f = io.open(path, "r")
  if not f then return nil end
  local meta = {
    key           = nil,
    created_at    = nil,
    last_activity = nil,
    first_msg_ts  = nil,
    msg_count     = 0,
    total_tokens  = 0,
  }
  for line in f:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local ok, e = pcall(json.decode, trimmed)
      if ok and type(e) == "table" then
        if e.type == "session" then
          -- Header: primeira fonte de created_at/key
          if not meta.key       then meta.key       = e.key end
          if not meta.created_at then meta.created_at = e.timestamp end
        elseif e.type == "message" then
          meta.msg_count = meta.msg_count + 1
          if e.timestamp then
            if not meta.first_msg_ts  then meta.first_msg_ts  = e.timestamp end
            meta.last_activity = e.timestamp
          end
          -- total_tokens rastreia o último contexto conhecido (>0)
          if e.tokens and e.tokens > 0 then meta.total_tokens = e.tokens end
        elseif e.type == "session_tokens" and e.tokens and e.tokens > 0 then
          meta.total_tokens = e.tokens
        end
      end
    end
  end
  f:close()
  return meta
end

-- ── Scan principal: registra órfãs no índice ────────────────────────────────
-- Retorna a quantidade de sessões recuperadas (0 = nada a fazer, sem I/O extra).
local function scan()
  local known = {}
  for _, s in ipairs(state._index.sessions) do
    known[s.id] = true
  end

  local recovered = 0
  for _, fname in ipairs(store.list_transcript_files()) do
    -- Nome do arquivo volta ao formato de ID: TUI-main-0333b7 -> TUI:main:0333b7
    local sid = fname:gsub("-", ":")
    if not known[sid] then
      local meta = extract_meta(sid)
      if meta then
        state._index.sessions[#state._index.sessions + 1] = {
          id               = sid,
          key              = meta.key or ("orphan_" .. fname),
          created_at       = meta.created_at or meta.first_msg_ts or "",
          updated_at       = meta.last_activity or meta.created_at or "",
          last_activity    = meta.last_activity or meta.created_at or "",
          last_reset       = nil,
          msg_count        = meta.msg_count,
          total_tokens     = meta.total_tokens,
          compaction_count = 0,
          model            = nil,
        }
        recovered = recovered + 1
      end
    end
  end

  if recovered > 0 then
    store.save_index(state._index)
  end
  return recovered
end

M.scan = scan
return M
