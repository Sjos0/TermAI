-- tools/error_feedback/feedback.lua
-- Gera mensagens cirurgicas do sistema para cada tipo de erro de ferramenta.
local M = {}

local examples = {
  Exec              = "ls -la ~/TermAI",
  Read              = "~/TermAI/arquivo.lua",
  Write             = "~/TermAI/arquivo.lua|||conteudo",
  Edit              = "~/TermAI/arquivo.lua|||texto antigo|||texto novo",
  Find              = "nome_do_arquivo",
  List              = "",
  calcular          = "2 + 2 * 3",
  memory_search     = "query de busca",
  pesquisar_web     = "termo de pesquisa",
  skill             = "nome_da_skill",
  sessoes_listar    = "",
  sessao_status     = "",
  sessoes_historico = "",
  restart           = "",
}

local function get_example(name)
  if not name then return "argumento" end
  local ex = examples[name]
  return (ex ~= nil) and ex or "argumento"
end

-- Gera string de feedback formatada para uma lista de erros.
-- Retorna "" se nao houver erros.
function M.generate(errors)
  if not errors or #errors == 0 then return "" end
  local parts = {}
  for _, err in ipairs(errors) do
    local msg = ""
    if err.type == "unknown_tool" then
      if err.suggestion then
        msg = string.format(
          "❌ Ferramenta '%s' nao existe.\n"
          .. "   💡 Voce quis dizer '%s'? Use:\n"
          .. "   <tool><name>%s</name><arg>%s</arg></tool>",
          err.tool_name, err.suggestion,
          err.suggestion, get_example(err.suggestion)
        )
      else
        msg = string.format(
          "❌ Ferramenta '%s' nao existe no sistema.\n"
          .. "   📋 Disponiveis: Exec, Read, Write, Edit, Find, List,\n"
          .. "      calcular, memory_search, pesquisar_web, skill,\n"
          .. "      sessoes_listar, sessao_status, sessoes_historico, restart\n"
          .. "   💡 Formato: <tool><name>NOME</name><arg>ARG</arg></tool>",
          err.tool_name
        )
      end
    elseif err.type == "empty_arg" then
      local ex = get_example(err.tool_name)
      if ex ~= "" then
        msg = string.format(
          "⚠️  Ferramenta '%s' requer argumento.\n"
          .. "   💡 Formato: <tool><name>%s</name><arg>%s</arg></tool>",
          err.tool_name, err.tool_name, ex
        )
      end
    elseif err.type == "malformed_outer_tag" then
      msg = string.format(
        "❌ Tag '%s' invalida. Use '<tool>' para chamar ferramentas:\n"
        .. "   <tool><name>NOME</name><arg>ARG</arg></tool>",
        err.found
      )
    elseif err.type == "malformed_name_tag" then
      msg = string.format(
        "❌ Tag '%s' invalida. Use '<name>' para o nome da ferramenta:\n"
        .. "   <tool><name>NOME</name><arg>ARG</arg></tool>",
        err.found
      )
    elseif err.type == "malformed_arg_tag" then
      msg = string.format(
        "❌ Tag '%s' invalida. Use '<arg>' para o argumento:\n"
        .. "   <tool><name>NOME</name><arg>ARG</arg></tool>",
        err.found
      )
    end
    if msg ~= "" then parts[#parts+1] = msg end
  end
  if #parts == 0 then return "" end
  local count  = #parts
  local header = "\n[INSTRUCAO DO SISTEMA] "
    .. count .. (count == 1 and " erro detectado" or " erros detectados")
    .. " no uso de ferramentas. Corrija e tente novamente:\n\n"
  return header .. table.concat(parts, "\n\n")
end

return M
