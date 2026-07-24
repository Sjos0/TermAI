-- tools/error_feedback/post_exec.lua
-- Analisa resultados pos-execucao e gera sugestoes cirurgicas.
local M = {}

-- Padroes de erro classificados do mais especifico para o mais generico.
local patterns = {
  { pat = "command not found",  sug = "Comando nao encontrado no Termux. Verifique se esta instalado." },
  { pat = "No such file",       sug = "Arquivo nao encontrado. Use Find para localizar o caminho correto." },
  { pat = "nao existe",         sug = "Recurso nao encontrado. Confirme o caminho antes de tentar novamente." },
  { pat = "not found",          sug = "Recurso nao encontrado. Confirme o caminho ou nome." },
  { pat = "is a directory",     sug = "O caminho aponta para um diretorio. Especifique um arquivo." },
  { pat = "Permission denied",  sug = "Permissao negada. Verifique as permissoes do arquivo ou diretorio." },
  { pat = "read%-only",         sug = "Sistema de arquivos somente-leitura. Verifique o destino." },
  { pat = "timeout",            sug = "Tempo limite excedido. Tente dividir em operacoes menores." },
  { pat = "syntax error",       sug = "Erro de sintaxe. Revise o codigo ou argumento antes de tentar novamente." },
  { pat = "syntaxe",            sug = "Erro de sintaxe detectado. Revise o formato do argumento." },
  { pat = "invalid",            sug = "Formato invalido. Revise os argumentos conforme a documentacao da ferramenta." },
}

-- Retorna feedback cirurgico (string) ou nil se a ferramenta nao retornou erro.
function M.analyze(tool_name, arg, result)
  if not result then return nil end
  if not result:match("^❌") then return nil end
  local result_low = result:lower()
  for _, entry in ipairs(patterns) do
    if result_low:match(entry.pat:lower()) then
      return string.format(
        "[FEEDBACK] Ferramenta '%s' retornou erro.\n"
        .. "  ❌ %s\n"
        .. "  💡 %s",
        tool_name,
        (result:match("^❌%s*(.-)%s*$") or result),
        entry.sug
      )
    end
  end
  -- Feedback generico para erros nao classificados
  return string.format(
    "[FEEDBACK] Ferramenta '%s' retornou erro.\n"
    .. "  ❌ %s\n"
    .. "  💡 Revise os argumentos e tente novamente:\n"
    .. "     <tool><name>%s</name><arg>ARGUMENTO</arg></tool>",
    tool_name,
    (result:match("^❌%s*(.-)%s*$") or result),
    tool_name
  )
end

return M
