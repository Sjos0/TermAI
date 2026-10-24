-- tests/google_grounding_pr5_spec/dobles.lua — mocks de config, io.popen, io.open e os.remove
-- usados pelas partes do spec. Instalados ao carregar; restaurados pela fachada.
local M = {}

local function load_json()
  local path = os.getenv("HOME") .. "/TermAI/json.lua"
  local f = io.open(path, "r")
  if f then
    f:close()
    return dofile(path)
  else
    return dofile("lib/json.lua")
  end
end

package.loaded["json"] = package.loaded["json"] or load_json()

-- ═══════════════════════════════════════════════════════
-- SETUP: Mocks
-- ═══════════════════════════════════════════════════════

local config_mod = require("config")
M.config_mod = config_mod
M.orig_load = config_mod.load
config_mod.load = function()
  return {
    web_tools = {
      enabled = true,
      google_grounding_key = "FAKE_API_KEY_FOR_TEST_12345"
    }
  }
end

M.captured_cmd = nil
M.captured_payload = nil
M.call_count = 0
M.mock_queue = {}

M.orig_popen = io.popen
io.popen = function(cmd)
  M.captured_cmd = cmd
  M.call_count = M.call_count + 1
  local response = table.remove(M.mock_queue, 1) or '{"steps":[{"type":"thought","text":"..."},{"type":"model_output","content":[{"type":"text","text":"Resposta mockada"}]}]}'
  return {
    read = function(self) return response end,
    close = function(self) end
  }
end

M.orig_remove = os.remove
os.remove = function(path) return true end

M.orig_open = io.open
io.open = function(path, mode)
  if mode == "w" then
    return {
      write = function(self, data) M.captured_payload = data end,
      close = function(self) end
    }
  end
  return M.orig_open(path, mode)
end

function M.reload()
  for k in pairs(package.loaded) do
    if k:find("google_grounding") then package.loaded[k] = nil end
  end
  package.loaded["agent.security"] = nil
  package.loaded["agent.security.validator"] = nil
  package.loaded["config"] = config_mod  -- garantir que config mock está ativo
  return require("providers.google_grounding")
end

return M
