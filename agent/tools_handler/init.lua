-- agent/tools_handler/init.lua
-- Orquestrador: M.parsear() + reexporta executar/executar_silent do executor.
local tools        = require("tools")
local sanitizer    = require("agent.tools_handler.text_sanitizer")
local block_parser = require("agent.tools_handler.block_parser")
local executor     = require("agent.tools_handler.executor")
local M            = {}

local ef = (function()
  local ok, m = pcall(require, "tools.error_feedback")
  return ok and m or nil
end)()

function M.parsear(resp)
  local ferramentas   = {}
  local invalid_tools = {}
  local texto_limpo   = resp
  local texto_para_analise = sanitizer.neutralize_code_fences(resp)
  local seen = {}
  texto_limpo = block_parser.parse_format(
    texto_para_analise, texto_limpo, ferramentas, seen,
    "<tool>", "</tool>", invalid_tools)
  texto_limpo = block_parser.parse_format(
    texto_para_analise, texto_limpo, ferramentas, seen,
    "<tool_call>", "</tool_call>", invalid_tools)
  texto_limpo = sanitizer.strip_orphan_tags(texto_limpo)

  local pre_feedback = ""
  if ef then
    local all_errors = {}
    local candidates = {}
    for name in pairs(tools.registry) do candidates[#candidates+1] = name end
    for _, inv in ipairs(invalid_tools) do
      local suggestion = ef.find_closest(inv.nome, candidates)
      all_errors[#all_errors+1] = { type = "unknown_tool", tool_name = inv.nome, suggestion = suggestion }
    end
    local xml_errors = ef.detect_malformed_xml(texto_para_analise)
    for _, xe in ipairs(xml_errors) do all_errors[#all_errors+1] = xe end
    for _, tool in ipairs(ferramentas) do
      if tool.arg == "" and not ef.accepts_empty_arg(tool.nome) then
        all_errors[#all_errors+1] = { type = "empty_arg", tool_name = tool.nome }
      end
    end
    if #all_errors > 0 then
      pre_feedback = ef.generate_feedback(all_errors)
    end
  end

  return texto_limpo:match("^%s*(.-)%s*$") or "", ferramentas, pre_feedback
end

M.executar        = executor.executar
M.executar_silent = executor.executar_silent

return M
