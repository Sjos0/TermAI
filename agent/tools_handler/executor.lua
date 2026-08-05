-- agent/tools_handler/executor.lua
-- Execucao de tool calls: executar() com UI e feedback, executar_silent() sem UI.
local ui    = require("ui")
local tools = require("tools")
local M     = {}

local ef = (function()
  local ok, m = pcall(require, "tools.error_feedback")
  return ok and m or nil
end)()

function M.executar(ferramentas)
  local resultados = {}
  for _, tool in ipairs(ferramentas) do
    local display = (tool.nome .. " | " .. tool.arg):gsub("\n", " ")
    if #display > 70 then display = display:sub(1, 70) .. "..." end
    ui.tool_start(display)
    local out = tools.call(tool.nome .. "|" .. tool.arg)
    local ok  = not out:match("^❌")
    ui.tool_end(display, out, ok)
    local result_text = out
    if not ok then
      local smart = ef and ef.post_exec_analyze(tool.nome, tool.arg, out)
      if smart then
        result_text = out .. "\n\n" .. smart
      else
        result_text = out
          .. "\n\n[INSTRUCAO DO SISTEMA] Ferramenta falhou. Verifique:\n"
          .. "1. Nome correto? Ferramentas: Exec, Read, Write, Edit, "
          .. "Find, List, pesquisar_web, sessao_status, memory_search, calcular\n"
          .. "2. Formato: <tool><name>NOME</name><arg>ARGUMENTO</arg></tool>\n"
          .. "3. Read antes de Edit/Write"
      end
    end
    resultados[#resultados + 1] = string.format(
      '<tool_result name="%s" status="%s">\n%s\n</tool_result>',
      tool.nome, (ok and "ok" or "erro"), result_text)
  end
  return table.concat(resultados, "\n\n")
end

function M.executar_silent(ferramentas)
  local resultados = {}
  for _, tool in ipairs(ferramentas) do
    local out = tools.call(tool.nome .. "|" .. tool.arg)
    local ok  = not out:match("^❌")
    resultados[#resultados + 1] = string.format(
      '<tool_result name="%s" status="%s">\n%s\n</tool_result>',
      tool.nome, (ok and "ok" or "erro"), out)
  end
  return table.concat(resultados, "\n\n")
end

return M
