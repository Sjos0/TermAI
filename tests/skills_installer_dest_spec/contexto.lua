-- tests/skills_installer_dest_spec/contexto.lua — Dependências e caminhos compartilhados
-- pelas partes do spec de destino do installer (Issue #72). Carregado uma vez.
local helpers = require("tools.helpers")

local M = {}

M.skills_utils = require("tools.skills.utils")
M.inst_utils   = require("tools.skills.skills_installer.utils")
M.PROJECT_ROOT = helpers.PROJECT_ROOT
M.GLOBAL       = M.PROJECT_ROOT .. "/skills"
M.MAIN_WS      = M.PROJECT_ROOT .. "/workspace/skills"

-- Lê um arquivo ou devolve nil (usado nos contratos estáticos).
function M.read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a") or ""
  f:close()
  return s
end

return M
