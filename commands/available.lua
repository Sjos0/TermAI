local M = {}

M.commands = {
  { name = "/models",   desc = "Gerenciar modelos de IA" },
  { name = "/config",   desc = "Configurações (Memory Flush e mais)" },
  { name = "/commands", desc = "Listar comandos disponíveis" },
  { name = "/new",      desc = "Iniciar uma nova sessão/conversa" },
  { name = "/reset",    desc = "Limpar a conversa atual (mantém o ID da sessão)" },
  { name = "/session",  desc = "Listar sessões  |  /session <id> para trocar" },
  { name = "/clear",    desc = "Deletar a conversa atual e migrar para outra sessão" },
  { name = "/restart",  desc = "Reiniciar a TUI" },
  { name = "/help",     desc = "Mostrar ajuda" },
  { name = "/sair",     desc = "Encerrar o TermAI" },
}

M.agent_commands = {}

function M.filter(prefix)
  if not prefix or prefix == "" then return M.commands end
  local results = {}
  local lower = prefix:lower()
  for _, cmd in ipairs(M.commands) do
    if cmd.name:lower():find(lower, 1, true) then
      results[#results + 1] = cmd
    end
  end
  return results
end

function M.get_docs()
  if #M.agent_commands == 0 then return "" end
  local doc = "### COMANDOS DO SISTEMA\n"
  doc = doc .. "Além das ferramentas acima, você pode executar estes comandos especiais via Exec:\n\n"
  for _, cmd in ipairs(M.agent_commands) do
    doc = doc .. "- " .. cmd.name .. ": " .. cmd.desc .. "\n"
    doc = doc .. "  Quando usar: " .. cmd.when .. "\n"
    doc = doc .. "  Como chamar: <tool><name>Exec</name><arg>" .. cmd.how .. "</arg></tool>\n\n"
  end
  return doc
end

return M
