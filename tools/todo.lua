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
    return nil, "[FAIL] todo_write: 'todos' deve ser um array não vazio."
  end
  for i, item in ipairs(todos) do
    if type(item) ~= "table" or not item.content or not item.status then
      return nil, "[FAIL] todo_write: item " .. i .. " precisa de 'content' e 'status'."
    end
    if item.status ~= "pending" and item.status ~= "in_progress" and item.status ~= "completed" then
      return nil, "[FAIL] todo_write: status inválido em item " .. i .. " ('" .. tostring(item.status) .. "')."
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

    local status = "[OK] Todas as tarefas concluídas. Lista arquivada na memória."
    if not arch_ok then status = "[WARN] Concluído, mas falha ao arquivar na memória." end
    if not del_ok  then status = status .. " [WARN] falha ao remover arquivo da sessão." end
    return status .. "\n" .. formatter.render(todos)
  end

  local saved, save_err = store.save(session_id, todos)
  if not saved then
    return "[FAIL] todo_write: falha ao salvar (" .. tostring(save_err) .. ")."
  end
  return formatter.render(todos)
end

function M.register(tools)
  tools.register(
    "todo_write",
    [==[Create or replace the task checklist for the current session. Always send the complete list: each call replaces the previous list entirely. Use it at the start of a task with three or more distinct steps, and update the statuses as you progress; several items can change in one call. Items are single-level, so do not create subtasks. Do not use it for a single-step request. When every item is sent as completed in the same call, the list is archived to memory and cleared; you do not need a separate call to clear it.]==],
    M.write,
    {
      type = "object",
      properties = {
        todos = {
          type = "array",
          description = "Complete task list. It replaces the previous list entirely.",
          items = {
            type = "object",
            properties = {
              content = {type = "string", description = "Short task description."},
              status  = {
                type = "string",
                enum = {"pending", "in_progress", "completed"},
                description = "Current task status."
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
