-- tools.lua — Fachada do sistema de ferramentas do TermAI.
-- v2: native tool calling via get_schema() e call_structured().
-- v3.1: Registra a nova ferramenta de leitura de páginas web "web_fetch".
--       get_schema() com ordem estável e determinística.
-- v3.2: call_structured(name, args, opts) com opts.skip_pretool.
local json   = require("json")
local tools  = {}
tools.registry = {}

local helpers    = require("tools.helpers")
local editor_mod = require("tools.editor")
local calc_mod   = require("tools.calculator")
local memory_mod = require("tools.memory")

function tools.register(name, description, func, schema)
  tools.registry[name] = {desc = description, execute = func, schema = schema}
end

require("tools.exec").register(tools)
require("tools.read").register(tools, helpers)
require("tools.grep").register(tools, helpers)
require("tools.find").register(tools, helpers)
require("tools.list").register(tools, helpers)
editor_mod.register_tools(tools, helpers)
require("tools.write").register(tools, helpers)
require("tools.sessions").register(tools)
require("tools.web").register(tools)
require("tools.web_fetch").register(tools, helpers)
calc_mod.register(tools)
memory_mod.register(tools)
require("tools.skills").register(tools)
require("tools.restart").register(tools)
require("tools.todo").register(tools)

function tools.call(cmd_string)
  local t_name, t_arg = cmd_string:match("^([^|]+)|(.*)$")
  if not t_name then return "❌ Erro: Sintaxe inválida." end
  t_name = t_name:match("^%s*(.-)%s*$")
  t_arg  = t_arg and t_arg:match("^%s*(.-)%s*$") or ""
  local tool = tools.registry[t_name]
  if not tool then return "❌ Erro: Ferramenta '" .. t_name .. "' não existe." end
  local hooks_engine = require("agent.hooks.engine")
  local allowed, reason = hooks_engine.run("PreToolUse", t_name, t_arg)
  if not allowed then
    return "❌ [PERMISSÃO NEGADA] " .. (reason or "Ferramenta bloqueada.")
  end
  local ok, res = pcall(tool.execute, t_arg)
  if not ok then return "❌ Erro interno: " .. tostring(res) end
  hooks_engine.run("PostToolUse", t_name, t_arg, res)
  return res
end

function tools.call_structured(name, args, opts)
  opts = opts or {}
  local tool = tools.registry[name]
  if not tool then return "❌ Ferramenta '" .. name .. "' não existe." end

  if tool.schema and tool.schema.required then
    local a = type(args) == "table" and args or {}
    for _, req in ipairs(tool.schema.required) do
      if not a[req] or a[req] == "" then
        return "❌ Argumento obrigatório ausente: '" .. req
               .. "' para ferramenta '" .. name .. "'"
      end
    end
  end

  local hooks_engine = require("agent.hooks.engine")
  local arg_str
  if type(args) == "table" then
    local primary
    if name == "Grep" then
      primary = string.format('"%s" in %s', args.pattern or "", args.path or ".")
    elseif name == "Read" and args.start_line then
      primary = string.format('%s:%s-%s', args.path or "", args.start_line, args.end_line or args.start_line)
    else
      primary = args.command or args.path  or args.query
             or args.expression or args.name or args.arg
             or args.session_id
    end
    if primary and type(primary) == "string" then
      arg_str = primary
    else
      local ok_j, enc = pcall(json.encode, args)
      arg_str = ok_j and enc or tostring(args)
    end
  else
    arg_str = tostring(args or "")
  end

  if not opts.skip_pretool then
    local allowed, reason = hooks_engine.run("PreToolUse", name, arg_str)
    if not allowed then
      return "❌ [PERMISSÃO NEGADA] " .. (reason or "Ferramenta bloqueada.")
    end
  end

  local ok, res = pcall(tool.execute, args)
  if not ok then return "❌ Erro interno: " .. tostring(res) end
  hooks_engine.run("PostToolUse", name, arg_str, res)
  return res
end

function tools.get_schema()
  local names = {}
  for name, data in pairs(tools.registry) do
    if data.schema then names[#names + 1] = name end
  end
  table.sort(names)
  local schema = {}
  for _, name in ipairs(names) do
    local data = tools.registry[name]
    schema[#schema + 1] = {
      type = "function",
      ["function"] = {
        name        = name,
        description = data.desc,
        parameters  = data.schema,
      }
    }
  end
  return #schema > 0 and schema or nil
end

function tools.get_docs()
  local doc = "FERRAMENTAS NATIVAS DISPONÍVEIS:\n"
  for name, data in pairs(tools.registry) do
    doc = doc .. "- " .. name .. ": " .. data.desc .. "\n"
  end
  return doc
end

return tools
