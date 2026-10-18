-- agent/loop.lua — Fachada do Loop ReAct do agente.
-- Refatorado a partir do monólito de 187 linhas (Issue #29).
-- v3.0: Interrupção atômica de turnos por cancelamento e injeção invisível
-- de System Messages de login, restart e cancelamento.
-- v3.1: boundary de subagents (#81) — tick + announce no fim de turno do pai.
--
-- Apenas orquestra o ciclo while e delega protocolo aos submódulos.
-- Contrato público: M.rodar(ctx, input, role, max_iter)
local ui               = require("ui")
local api              = require("agent.api")
local system_messages  = require("agent.loop.system_messages")
local json_path        = require("agent.loop.json_path")
local xml_path         = require("agent.loop.xml_path")

local M = {}

local function parent_boundary(ctx)
  if not ctx or ctx.is_subagent then return end
  pcall(function()
    require("tools.subagents.scheduler").on_parent_boundary(ctx)
  end)
end

function M.rodar(ctx, input, role, max_iter)
  _G.__termai_ctx = ctx

  local cur_text   = input
  local cur_role   = role or "user"
  local iter       = 0
  local elapsed    = 0
  local raw_limit  = max_iter or ctx.MAX_ITER
  local limit      = (raw_limit == 0) and math.huge or raw_limit
  local stream_complete   = true
  local last_reasoning    = ""
  local vazio_count       = 0
  local MAX_VAZIO_RETRIES = (ctx.cfg
    and ctx.cfg.agents
    and ctx.cfg.agents.defaults
    and ctx.cfg.agents.defaults.hooks
    and ctx.cfg.agents.defaults.hooks.max_vazio_retries) or 2
  local spinner_started = false

  cur_text, spinner_started = system_messages.prepare_user_turn(ctx, cur_text, cur_role)

  while iter < limit do
    if not spinner_started then ui.start_thinking() end
    spinner_started = false
    local resp, is_overflow, done_flag, reasoning, tool_calls =
      api.pensar_stream(ctx, cur_text, cur_role)
    elapsed = elapsed + ui.stop_thinking()
    if done_flag ~= nil then stream_complete = done_flag end
    if is_overflow then
      parent_boundary(ctx)
      return resp, elapsed, false, true, stream_complete, ""
    end

    if tool_calls and #tool_calls > 0 then
      local result = json_path.handle(
        ctx, resp, tool_calls, stream_complete, elapsed, last_reasoning
      )
      if result.action == "return" then
        parent_boundary(ctx)
        return result.resp, result.elapsed, result.flush_done,
               result.is_overflow, result.stream_complete, result.last_reasoning
      end
      parent_boundary(ctx)
      iter = iter + (result.iter_delta or 0)
      cur_text = result.cur_text
      cur_role = result.cur_role
      last_reasoning = result.last_reasoning or ""
    else
      local result = xml_path.handle(
        ctx, resp, reasoning, stream_complete, elapsed,
        vazio_count, MAX_VAZIO_RETRIES
      )
      if result.action == "return" then
        parent_boundary(ctx)
        return result.resp, result.elapsed, result.flush_done,
               result.is_overflow, result.stream_complete, result.last_reasoning
      elseif result.action == "retry" then
        vazio_count = result.vazio_count
        cur_text = result.cur_text
        cur_role = result.cur_role
      else
        parent_boundary(ctx)
        iter = iter + (result.iter_delta or 0)
        cur_text = result.cur_text
        cur_role = result.cur_role
        last_reasoning = result.last_reasoning or ""
      end
    end
  end

  parent_boundary(ctx)
  ui.agent_limit(limit)
  return "", elapsed, false, false, stream_complete, ""
end

return M
