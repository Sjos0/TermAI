-- tools/todo.lua — Fachada da ferramenta de checklist de tarefas (todo_write).
-- Substitui a lista inteira a cada chamada (sem subtarefas, nível único).
-- Quando todos os itens chegam completed na mesma chamada, a lista é
-- arquivada na memória de longo prazo e o arquivo de sessão é removido.
local store     = require("tools.todo.store")
local formatter = require("tools.todo.formatter")
local archiver  = require("tools.todo.archiver")

local M = {}

local function validar_todos(todos)
  if type(todos) ~= "table" or #todos == 0 then
    return nil, "❌ todo_write: 'todos' deve ser um array não vazio."
  end
  for i, item in ipairs(todos) do
    if type(item) ~= "table" or not item.content or not item.status then
      return nil, "❌ todo_write: item " .. i .. " precisa de 'content' e 'status'."
    end
    if item.status ~= "pending" and item.status ~= "in_progress" and item.status ~= "completed" then
      return nil, "❌ todo_write: status inválido em item " .. i .. " ('" .. tostring(item.status) .. "')."
    end
  end
  return true
end

-- Verifica se TODOS os itens da lista estão marcados como concluídos.
local function todas_concluidas(todos)
  for _, item in ipairs(todos) do
    if item.status ~= "completed" then return false end
  end
  return true
end

function M.write(args)
  local todos = type(args) == "table" and args.todos or nil
  local ok, err = validar_todos(todos)
  if not ok then return err end

  local session    = require("session")
  local session_id = session.current()

  if todas_concluidas(todos) then
    local arch_ok = archiver.archive(todos)
    pcall(function() require("tools.memory").invalidate_cache() end)
    local del_ok = store.delete(session_id)

    local status = "✅ Todas as tarefas concluídas. Lista arquivada na memória."
    if not arch_ok then status = "⚠️ Concluído, mas falha ao arquivar na memória." end
    if not del_ok  then status = status .. " ⚠️ falha ao remover arquivo da sessão." end
    return status .. "\n" .. formatter.render(todos)
  end

  local saved, save_err = store.save(session_id, todos)
  if not saved then
    return "❌ todo_write: falha ao salvar (" .. tostring(save_err) .. ")."
  end
  return formatter.render(todos)
end

function M.register(tools)
  tools.register(
    "todo_write",
    "Cria ou atualiza a lista de tarefas da sessão atual. SEMPRE envie a lista "
    .. "COMPLETA (substitui a anterior inteira, não é incremental). Use no início "
    .. "de tarefas com 3+ passos distintos para planejar, e atualize o status "
    .. "conforme avança (pode marcar várias de uma vez). Adicione itens novos "
    .. "descobertos no meio da tarefa. Checklist de nível único, sem subtarefas. "
    .. "Quando TODOS os itens forem enviados como 'completed' na mesma chamada, "
    .. "a lista é arquivada automaticamente na memória e removida — não é preciso "
    .. "chamar de novo para 'limpar'.",
    M.write,
    {
      type = "object",
      properties = {
        todos = {
          type = "array",
          description = "Lista completa de tarefas. Substitui a lista anterior inteira.",
          items = {
            type = "object",
            properties = {
              content = {type = "string", description = "Descrição curta da tarefa."},
              status  = {
                type = "string",
                enum = {"pending", "in_progress", "completed"},
                description = "Status atual da tarefa."
              }
            },
            required = {"content", "status"}
          }
        }
      },
      required = {"todos"}
    }
  )
end

return M
