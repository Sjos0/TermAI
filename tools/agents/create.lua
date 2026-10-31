-- tools/agents/create.lua — Cria um agente independente depois da confirmação do usuário.
local paths     = require("tools.agents.paths")
local workspace = require("tools.agents.workspace")
local registry  = require("tools.agents.registry")
local M = {}

local function blank(s)
  return type(s) ~= "string" or s:match("^%s*$") ~= nil
end

-- args: id, nome, identidade, funcoes, confirmado. Retorna texto para o modelo.
function M.create(args)
  args = type(args) == "table" and args or {}
  if args.confirmed ~= true then
    return "[FAIL] agents_create: pergunte ao usuário o nome e as funções do agente e só então envie confirmed=true."
  end
  if not paths.valid_id(args.id) then
    return "[FAIL] agents_create: id inválido (minúsculas, números, _ ou -, 2 a 32 caracteres; 'main' é reservado)."
  end
  if registry.exists(args.id) then
    return "[FAIL] agents_create: o agente '" .. args.id .. "' já existe."
  end
  if blank(args.identity) then return "[FAIL] agents_create: 'identity' é obrigatório (vai para IDENTITY.md)." end
  if blank(args.functions) then return "[FAIL] agents_create: 'functions' é obrigatório (vai para AGENTS.md)." end

  local ok, err = workspace.create(args.id, args.name, args.identity, args.functions)
  if not ok then
    workspace.remove(args.id)
    return "[FAIL] agents_create: " .. tostring(err)
  end

  local reg_ok, reg_err = registry.add(args.id, args.name)
  if not reg_ok then
    workspace.remove(args.id)
    return "[FAIL] agents_create: " .. tostring(reg_err)
  end

  return "[OK] Agente '" .. args.id .. "' criado em " .. paths.workspace_abs(args.id)
    .. ". USER.md copiado do orquestrador."
end

return M
