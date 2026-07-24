-- session/store/index.lua — Controle do índice das sessões (sessions.json).
local json = require("json")
local common = require("session.store.common")

local M = {}

local SESSIONS_FILE = common.SESSIONS_DIR .. "/sessions.json"
local LEGACY_INDEX  = common.SESSIONS_DIR .. "/index.json"

function M.ensure_dir()
  local ok, _, code = os.execute('mkdir -p "' .. common.SESSIONS_DIR .. '"')
  if not ok then
    io.write("\27[38;5;203m⚠️  [Medula] Falha crítica ao criar diretório de dados: " .. tostring(common.SESSIONS_DIR) .. "\27[0m\n")
    io.flush()
    return false
  end
  return true
end

-- ── Migração automática do store ────────────────────────────────────────────
local function migrate_store()
  local sf = io.open(SESSIONS_FILE, "r")
  if sf then sf:close(); return end
  local lf = io.open(LEGACY_INDEX, "r")
  if lf then
    lf:close()
    os.rename(LEGACY_INDEX, SESSIONS_FILE)
  end
end

-- ── Index (sessions.json) Atômico com Rename POSIX ──────────────────────────
function M.load_index()
  M.ensure_dir()
  migrate_store()
  local f = io.open(SESSIONS_FILE, "r")
  if not f then return { active = nil, sessions = {} } end
  local raw = f:read("*a"); f:close()
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then
    return { active = nil, sessions = {} }
  end
  if not data.sessions then data.sessions = {} end
  return data
end

function M.save_index(data)
  if not M.ensure_dir() then return false end
  local tmp_file = SESSIONS_FILE .. ".tmp"
  local f = io.open(tmp_file, "w")
  if not f then return false end
  f:write(json.encode(data))
  f:close()

  local ok, err = os.rename(tmp_file, SESSIONS_FILE)
  if not ok then
    os.remove(tmp_file)
    return false
  end
  return true
end

return M
