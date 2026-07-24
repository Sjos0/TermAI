-- agent/loop/tool_runner/suffix.lua — Geração de sufixos de contexto e tags XML.
local M = {}

function M.build_system_suffix(ctx, elapsed_ms, last_app)
  local suffix = "\n\n[SYSTEM: Review your progress. Maintain strict code coherence and verify syntax. Do not duplicate actions, repeat previous responses, or hallucinate variables/files. Ensure all brackets, ends, and scopes are closed before replying.]"

  if elapsed_ms then
    suffix = suffix .. string.format("\n[RESOURCE METRICS: Execution time: %dms]", elapsed_ms)
  end

  if last_app and last_app ~= "CANCELLED" then
    suffix = suffix .. string.format("\n[SYSTEM MESSAGE: Security permission for this action was: %s]", last_app)
  end

  if ctx.session_files then
    local read_list = {}
    for p in pairs(ctx.session_files.read.set or {}) do read_list[#read_list + 1] = p end
    table.sort(read_list)

    local written_list = {}
    for p in pairs(ctx.session_files.written.set or {}) do written_list[#written_list + 1] = p end
    table.sort(written_list)

    local edited_list = {}
    for p in pairs(ctx.session_files.edited.set or {}) do edited_list[#edited_list + 1] = p end
    table.sort(edited_list)

    if #read_list > 0 or #written_list > 0 or #edited_list > 0 then
      suffix = suffix .. "\n<workspace_attention>"
      if #read_list > 0 then
        suffix = suffix .. "\n  <read_files>" .. table.concat(read_list, ", ") .. "</read_files>"
      end
      if #written_list > 0 then
        suffix = suffix .. "\n  <created_files>" .. table.concat(written_list, ", ") .. "</created_files>"
      end
      if #edited_list > 0 then
        suffix = suffix .. "\n  <edited_files>" .. table.concat(edited_list, ", ") .. "</edited_files>"
      end
      suffix = suffix .. "\n</workspace_attention>"
    end
  end

  local todo_ok, todo_block = pcall(function()
    local session_mod = require("session")
    local todo_store  = require("tools.todo.store")
    local todo_fmt    = require("tools.todo.formatter")
    local todos = todo_store.load(session_mod.current())
    if #todos == 0 then return nil end
    return todo_fmt.render(todos)
  end)
  if todo_ok and todo_block then
    suffix = suffix .. "\n<todo_status>\n" .. todo_block .. "\n</todo_status>"
  end

  return suffix
end

return M
