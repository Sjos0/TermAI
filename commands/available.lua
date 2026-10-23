local M = {}

M.commands = {
  { name = "/models",   desc = "Gerenciar modelos de IA" },
  { name = "/config",   desc = "Configurações (Memory Flush e mais)" },
  { name = "/commands", desc = "Listar comandos disponíveis" },
  { name = "/new",      desc = "Iniciar uma nova sessão/conversa" },
  { name = "/reset",    desc = "Limpar a conversa atual (mantém o ID da sessão)" },
  { name = "/session",  desc = "Listar sessões  |  /session <id> para trocar" },
  { name = "/clear",    desc = "Deletar a conversa atual e migrar para outra sessão" },
  { name = "/compact",  desc = "Compactação manual (opcional: /compact foque em X)" },
  { name = "/status",   desc = "Ver status do TermAI" },
  { name = "/subagents", desc = "Listar, ver log, info ou encerrar subagentes" },
  { name = "/restart",  desc = "Reiniciar a TUI" },
  { name = "/help",     desc = "Mostrar ajuda dos slash commands" },
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

-- Bloco do system prompt com os comandos da TUI (issue #70; decisão do Arquiteto: fonte = M.commands).
-- São comandos digitados pelo usuário, NÃO ferramentas: o modelo não os executa via Exec.
function M.get_docs()
  if not M.commands or #M.commands == 0 then return "" end
  local doc = "### COMANDOS DA TUI\n"
  doc = doc .. "Comandos que o usuário digita na TUI (não são ferramentas; você não os executa):\n"
  for _, cmd in ipairs(M.commands) do
    local name = type(cmd) == "table" and (cmd.name or cmd.cmd or cmd[1]) or cmd
    local desc = type(cmd) == "table" and (cmd.desc or cmd.description) or nil
    doc = doc .. "- " .. tostring(name) .. ((desc and desc ~= "") and (": " .. tostring(desc)) or "") .. "\n"
  end
  return doc
end

return M
