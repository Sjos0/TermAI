-- channels/telegram.lua — Fachada do canal Telegram. Interface pública: M.run(ctx)
local config           = require("config")
local approval_backend = require("agent.hooks.approval_backend")
local ui               = require("ui")
local api              = require("channels.telegram.api")
local offset_store     = require("channels.telegram.offset_store")
local approval         = require("channels.telegram.approval")
local stream_sink      = require("channels.telegram.stream_sink")
local bridge           = require("channels.telegram.bridge")

local M = {}

function M.run(ctx)
  local token = config.get("channels.telegram.token")
  if not token or token == "" then
    io.stderr:write("channels.telegram.token não configurado em ~/.TermAI/config.json\n")
    os.exit(1)
  end

  approval_backend.set_tool_backend(approval.ask_tool)
  approval_backend.set_bash_backend(approval.ask_bash)
  ui.set_sink(stream_sink)
  ctx.channel = "telegram"

  while true do
    local offset  = offset_store.load()
    local updates = api.get_updates(token, offset, 25)
    if updates then
      for _, upd in ipairs(updates) do
        offset_store.save(upd.update_id + 1)
        pcall(bridge.handle_update, ctx, token, upd)
      end
    end
  end
end

return M
