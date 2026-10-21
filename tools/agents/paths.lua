-- tools/agents/paths.lua — Caminhos dos agentes independentes (~/.TermAI/agents/<id>/workspace).
local M = {}

-- Testes trocam a raiz para não tocar no ~/.TermAI real.
M.base_override = nil

function M.home()
  return os.getenv("HOME") or "/data/data/com.termux/files/home"
end

function M.root()
  return M.base_override or (M.home() .. "/.TermAI")
end

-- Relativo à raiz, no formato de agents.list[].workspace (igual ao "workspace" do main).
function M.workspace_rel(id)
  return "agents/" .. id .. "/workspace"
end

function M.workspace_abs(id)
  return M.root() .. "/" .. M.workspace_rel(id)
end

-- USER.md do orquestrador: copiado para todo agente independente novo.
function M.main_user_md()
  return M.root() .. "/workspace/USER.md"
end

-- Id seguro para usar em caminho e shell. 'main' é reservado para o orquestrador.
function M.valid_id(id)
  return type(id) == "string" and id ~= "main"
    and id:match("^[a-z][a-z0-9_-]+$") ~= nil and #id >= 2 and #id <= 32
end

return M
