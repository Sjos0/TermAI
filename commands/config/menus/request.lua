-- commands/config/menus/request.lua — Menu de configuração de requisições (Padrão Fachada).
local ui = require("commands.models.ui")
local view = require("commands.config.menus.request.view")
local actions = require("commands.config.menus.request.actions")

local M = {}

function M.run(ctx)
  while true do
    local req = ctx.cfg.agents.defaults.request or {}
    view.print_header()
    view.print_status(req)
    view.print_options()

    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end

    if     ch == "1" then actions.change_timeout(ctx)
    elseif ch == "2" then actions.change_max_retries(ctx)
    elseif ch == "3" then actions.change_retry_mode(ctx)
    elseif ch == "4" then actions.restore_defaults(ctx)
    elseif ch == "5" then actions.change_wait_timeout(ctx)
    elseif ch == "6" then actions.change_request_mode(ctx)
    elseif ch == "7" then actions.change_reasoning_effort(ctx)
    elseif ch == "8" then actions.change_language(ctx)
    end
  end
end

return M
