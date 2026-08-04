-- agent/hooks/approval_backend.lua — Registro de backends alternativos de
-- aprovação (usado por canais sem TTY, ex: channels/telegram). Sem backend
-- registrado, tools/exec/permissions_ui.lua e agent/hooks/bash_patterns/ui.lua
-- mantêm 100% o comportamento original de terminal.
local M = {}
local tool_fn, bash_fn = nil, nil

function M.set_tool_backend(fn) tool_fn = fn end
function M.set_bash_backend(fn) bash_fn = fn end
function M.tool_backend() return tool_fn end
function M.bash_backend() return bash_fn end

return M
