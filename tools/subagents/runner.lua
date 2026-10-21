-- tools/subagents/runner.lua — Roda o clone em turno próprio e descarta o contexto ao sair.
local stream     = require("ui.stream")
local child_ctx  = require("tools.subagents.child_ctx")

local M = {}

-- Sink que engole o texto do clone: o usuário vê só as ferramentas e o resultado.
local function silent_sink()
  local buf = {}
  return {
    start  = function() buf = {} end,
    token  = function(tok) buf[#buf + 1] = tok end,
    finish = function() return table.concat(buf), "" end,
  }
end

local function last_assistant_text(msgs)
  for i = #msgs, 1, -1 do
    local m = msgs[i]
    if m.role == "assistant" and type(m.content) == "string" and m.content ~= "" then
      return m.content
    end
  end
  return ""
end

-- Retorna (texto_final) ou (nil, motivo). O contexto do clone some ao fim da função.
function M.run(parent, task)
  local built, ctx = pcall(child_ctx.build, parent)
  if not built then return nil, "falha ao montar o clone: " .. tostring(ctx) end

  local subagents = require("tools.subagents")
  local loop      = require("agent.loop")
  local prev_sink = stream.get_sink()

  stream.set_sink(silent_sink())
  local ok, resp, _, _, overflow = pcall(loop.rodar, ctx, task, "user", ctx.MAX_ITER)
  stream.set_sink(prev_sink)
  subagents.bind(parent)

  if not ok then return nil, tostring(resp) end
  if overflow then return nil, "contexto do clone estourou" end

  local text = (type(resp) == "string" and resp ~= "") and resp or last_assistant_text(ctx.msgs)
  ctx.msgs = nil
  return text
end

return M
