-- tools/todo/formatter.lua — Constrói o checklist markdown exibido ao usuário e ao modelo.
local M = {}

local MARCADOR = {
  pending     = "[ ]",
  in_progress = "[-]",
  completed   = "[x]",
}

-- Recebe array de {content, status} e devolve string de checklist pronta.
function M.render(todos)
  local concluidas = 0
  local linhas = {}
  for _, item in ipairs(todos) do
    if item.status == "completed" then concluidas = concluidas + 1 end
    linhas[#linhas + 1] = (MARCADOR[item.status] or "[ ]") .. " " .. item.content
  end

  local cabecalho = string.format("📋 Lista de Tarefas (%d/%d concluídas)", concluidas, #todos)
  table.insert(linhas, 1, cabecalho)
  return table.concat(linhas, "\n")
end

return M
