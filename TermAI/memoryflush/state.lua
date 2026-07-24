-- memoryflush/state.lua — Gerenciamento de estado, checkpoints e I/O de arquivos locais.
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local _state_file   = HOME .. "/.TermAI/.flush_state"
local _ultimo_flush = nil
local _agent_id     = "main"

local function load_state()
  local f = io.open(_state_file, "r")
  if not f then return 0 end
  local val = tonumber(f:read("*a")) or 0
  f:close()
  return val
end

local function save_state(val)
  local f = io.open(_state_file, "w")
  if f then f:write(tostring(val)); f:close() end
end

function M.init(agent_base, agent_id)
  _agent_id     = agent_id or "main"
  _state_file   = agent_base .. "/.flush_state"
  _ultimo_flush = load_state()
end

function M.get_state_file() return _state_file end
function M.get_agent_id()   return _agent_id   end

function M.get_ultimo(tokens)
  if _ultimo_flush == nil then _ultimo_flush = load_state() end
  -- v2.4: Sincronização ativa proporcional (50%) para compactação
  -- Em vez de resetar para 0 e forçar um flush inútil imediato, sincroniza
  -- o marco de início com o token reduzido atual.
  if tokens ~= nil and _ultimo_flush > (tokens * 1.5) then
    _ultimo_flush = tokens
    save_state(_ultimo_flush)
  end
  return _ultimo_flush
end

function M.marcar_flush(tokens)
  _ultimo_flush = tokens or 0
  save_state(_ultimo_flush)
end

return M
