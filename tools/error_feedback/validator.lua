-- tools/error_feedback/validator.lua
-- Valida tool calls e detecta tags XML malformadas.
local fuzzy     = require("tools.error_feedback.fuzzy_match")
local whitelist = require("tools.error_feedback.tool_whitelist")
local M = {}

-- Tags externas invalidas em vez de <tool>
local bad_outer = { "ferramenta", "chamada", "tool_use", "fn", "func", "comando" }
-- Tags de nome invalidas em vez de <name>
local bad_name  = { "nome", "tool_name", "function_name", "name_tag" }
-- Tags de argumento invalidas em vez de <arg>
local bad_arg   = { "argumento", "parametro", "param", "input", "parameter" }

-- Detecta tags XML malformadas no texto. Retorna lista de erros.
function M.detect_malformed_xml(text)
  if not text or text == "" then return {} end
  local errors    = {}
  local seen_tags = {}
  for _, tag in ipairs(bad_outer) do
    if not seen_tags[tag]
       and (text:find("<" .. tag .. "[%s>]") or text:find("</" .. tag .. ">")) then
      seen_tags[tag] = true
      errors[#errors+1] = { type = "malformed_outer_tag", found = "<"..tag..">", expected = "<tool>" }
    end
  end
  for _, tag in ipairs(bad_name) do
    if not seen_tags[tag] and text:find("<" .. tag .. ">") then
      seen_tags[tag] = true
      errors[#errors+1] = { type = "malformed_name_tag", found = "<"..tag..">", expected = "<name>" }
    end
  end
  for _, tag in ipairs(bad_arg) do
    if not seen_tags[tag] and text:find("<" .. tag .. ">") then
      seen_tags[tag] = true
      errors[#errors+1] = { type = "malformed_arg_tag", found = "<"..tag..">", expected = "<arg>" }
    end
  end
  return errors
end

-- Valida tool calls contra o registry.
-- Retorna: valid_tools, errors
function M.validate(tool_calls, registry)
  if not tool_calls or #tool_calls == 0 then return {}, {} end
  local valid, errors = {}, {}
  local candidates = {}
  for name in pairs(registry or {}) do candidates[#candidates+1] = name end
  for _, tool in ipairs(tool_calls) do
    local nome = tool.nome
    local arg  = tool.arg or ""
    if not registry[nome] then
      local suggestion, dist = fuzzy.find_closest(nome, candidates)
      errors[#errors+1] = { type = "unknown_tool", tool_name = nome, suggestion = suggestion, distance = dist }
    else
      if arg == "" and not whitelist.accepts_empty_arg(nome) then
        errors[#errors+1] = { type = "empty_arg", tool_name = nome }
      end
      valid[#valid+1] = tool
    end
  end
  return valid, errors
end

return M
