-- tools.lua — Fachada do sistema de ferramentas do TermAI.
-- v2: native tool calling via get_schema() e call_structured().
-- v3.1: Registra a nova ferramenta de leitura de páginas web "web_fetch".
--       get_schema() com ordem estável e determinística.
-- v3.2: call_structured(name, args, opts) com opts.skip_pretool.
-- v3.3: get_schema/get_docs aceitam disabled_set (Issue #32); defesa em call*.
-- Contrato de nomes (issue #71; PR #111 renomeou as tools para nomes em inglês, sem alias).
--   filesystem/shell: PascalCase (Exec, Read, Grep, Find, List, Write, Edit)
--   demais tools: snake_case ou minúsculo (web_search, calculate, sessions_list, web_fetch, ...)
-- Fonte de verdade: tools.registry. Listas manuais de nomes são o problema da #66.
-- Tool NOVA: seguir o padrão do grupo e manter a description coerente.
-- Renomear quebra native calling, XML, disabled_tools e hooks: exige issue própria com alias.
local json   = require("json")
local helpers    = require("tools.helpers")
local tools  = {}
tools.registry = {}

function tools.register(name, description, func, schema)
  tools.registry[name] = {desc = description, execute = func, schema = schema}
end

-- Converte array ou set em tabela de lookup O(1). Aceita nil.
local function to_disabled_set(disabled)
  if not disabled then return {} end
  if type(disabled) ~= "table" then return {} end
  local set = {}
  -- Já é set? (chaves string -> true)
  local is_set = false
  for k, v in pairs(disabled) do
    if type(k) == "string" and v == true then
      is_set = true
      break
    end
  end
  if is_set then
    for k, v in pairs(disabled) do
      if v then set[k] = true end
    end
  else
    for _, name in ipairs(disabled) do
      if type(name) == "string" then set[name] = true end
    end
  end
  return set
end

require("tools.registro")(tools, helpers, json)
require("tools.chamada")(tools, helpers, json, to_disabled_set)
require("tools.schema")(tools, helpers, json, to_disabled_set)

return tools
