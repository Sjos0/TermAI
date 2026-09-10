-- agent/loop/json_path.lua — Caminho nativo JSON do loop ReAct (tool_calls).
local ui          = require("ui")
local tool_runner = require("agent.loop.tool_runner")
local response_utils = require("agent.loop.response_utils")

local M = {}

--- Processa um turno com tool_calls nativos.
-- @param ctx table
-- @param resp string Resposta bruta da API
-- @param tool_calls table Lista de tool_calls
-- @param stream_complete boolean
-- @param elapsed number Tempo acumulado até agora
-- @return table Resultado estruturado:
--   { action = "return", ... }  — interrompe o loop (cancel ou FLUSH_DONE)
--   { action = "continue", iter_delta = 1, cur_text = nil, cur_role = nil, last_reasoning = "" }
function M.handle(ctx, resp, tool_calls, stream_complete, elapsed)
  local resp_stripped = response_utils.strip_flush_tag(resp)
  if resp_stripped ~= "" then ui.ai_msg_stream(resp_stripped) end

  tool_runner.run_batch(ctx, tool_calls)

  -- Cancelamento atômico do turno
  if ctx.tool_cancelled then
    ctx.tool_cancelled = nil
    ctx.prev_command_cancelled = true
    return {
      action = "return",
      resp = resp,
      elapsed = elapsed,
      flush_done = false,
      is_overflow = false,
      stream_complete = stream_complete,
      last_reasoning = "",
    }
  end

  if resp:match("%[FLUSH_DONE%]") then
    return {
      action = "return",
      resp = resp,
      elapsed = elapsed,
      flush_done = true,
      is_overflow = false,
      stream_complete = stream_complete,
      last_reasoning = "",
    }
  end

  return {
    action = "continue",
    iter_delta = 1,
    cur_text = nil,
    cur_role = nil,
    last_reasoning = "",
  }
end

return M
