-- tools/exec/permissions/mode.lua — Modo de permissão e command_exists
local config_mod = require("config")

local M = {}

-- Override só em memória do processo (ex.: TermAI run --permitir-sempre).
-- Nunca é salvo no config.json.
local runtime_override = nil

-- Define o modo para este processo apenas (não persiste no config)
function M.set_runtime(mode)
  runtime_override = mode and tostring(mode):lower() or nil
end

-- Retorna o modo de permissão atual (default, acceptEdits, bypass)
function M.get()
  if runtime_override then return runtime_override end
  local cfg = {}
  pcall(function() cfg = config_mod.load() end)
  local mode = cfg.permissions and cfg.permissions.defaultMode or "default"
  return mode:lower()
end

-- Seta o modo de permissão (para a sessão/persistente)
function M.set(mode)
  local cfg = {}
  pcall(function() cfg = config_mod.load() end)
  cfg.permissions = cfg.permissions or {}
  cfg.permissions.defaultMode = mode
  pcall(function() config_mod.save(cfg) end)
end

-- Escapa uma string para uso seguro entre aspas simples em shell (evita injeção)
local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Verifica se um nome de comando existe de fato no PATH (mesmo 'sh' usado pelo executor real).
-- Puramente informativo: nunca bloqueia nem auto-aprova, só evita que texto solto do
-- agente (ex: "Vou trazer os arquivos...") pareça uma ação legítima no diálogo de permissão.
function M.command_exists(name)
  if not name or name == "" then return true end
  local h = io.popen("command -v -- " .. shell_quote(name) .. " >/dev/null 2>&1; echo $?")
  if not h then return true end -- indisponível: não muda o comportamento atual
  local res = h:read("*l")
  h:close()
  return res == "0"
end

return M
