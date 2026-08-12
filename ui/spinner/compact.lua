-- ui/spinner/compact.lua — modos compact/expanded thinking e orquestração.
local launch = require("ui.spinner.launch")
local timing = require("ui.spinner.timing")
local retry  = require("ui.spinner.retry")
local M = {}

local function get_thinking_mode()
  local ok, config_mod = pcall(require, "config")
  if ok and config_mod then
    local ok_val, val = pcall(config_mod.get, "agents.defaults.thinking_mode")
    if ok_val and val then
      return val
    end
  end
  return "expanded"
end

--- Inicia o ciclo de thinking (mata spinner anterior, reseta estado, lança modo).
function M.start_thinking(label)
  launch.kill_spinner()
  retry.clear_retry_lines()
  timing.reset_timers()

  local ok_state, state = pcall(require, "ui.stream.state")
  if ok_state and state and state._s then
    state._s.compact_thinking_stopped = false
  end

  if label ~= "Injetando" then
    launch.set_inject_flag()
  end

  local tmode = get_thinking_mode()
  if tmode == "compact" then
    launch.launch_compact()
  else
    launch.launch()
  end
end

--- Atualiza label para "Requisitando" (flag de inject).
function M.update_label()
  launch.set_inject_flag()
end

--- Sinaliza ao spinner compacto que o primeiro token de reasoning chegou.
function M.mark_reasoning_started()
  timing.mark_reasoning()
  launch.set_reasoning_flag()
end

--- Reinicia o spinner após falha de tentativa (rearma guard de animação).
function M.restart_spinner()
  launch.kill_spinner()
  -- Patch Claude Sonnet 5 (2026-08-04): Rearma o guard de animação.
  -- Sem isso, stop_thinking_and_print_compact() vê _anim_start == nil
  -- (zerado pelo stream_end() da tentativa que falhou) e não faz nada —
  -- o processo sh relançado abaixo nunca é morto e fica escrevendo
  -- por cima da resposta que chega na tentativa seguinte.
  timing.reset_timers()
  launch.set_inject_flag()

  local tmode = get_thinking_mode()
  if tmode == "compact" then
    launch.launch_compact()
  else
    launch.launch()
  end
end

--- Para o spinner compacto e imprime "Pensou (duração)" se houve reasoning.
function M.stop_thinking_and_print_compact()
  if not timing.get_anim_start() then return end
  local elapsed_ms = timing.elapsed_ms()
  launch.kill_spinner()
  timing.clear_anim()

  local LBLUE  = "\27[38;5;117m"
  local YELLOW = "\27[38;5;220m"
  local RESET  = "\27[0m"
  -- Patch GLM 5.2 (2026-08-03): só exibe "Pensou" se houve reasoning real.
  -- Se _reasoning_start_ms é nil, nenhum token de reasoning chegou — limpa
  -- spinner silenciosamente e pula pra resposta.
  if timing.get_reasoning_start_ms() then
    io.write("\r\27[K" .. LBLUE .. "⬤ " .. "Pensou " .. RESET
      .. YELLOW .. "(" .. timing.format_duration(elapsed_ms) .. ")" .. RESET .. "\n\n")
  else
    io.write("\r\27[K\n")
  end
  io.flush()
end

--- Para o thinking conforme o modo ativo; retorna elapsed em segundos.
function M.stop_thinking()
  local tmode = get_thinking_mode()
  if tmode == "compact" then
    local ok_state, state = pcall(require, "ui.stream.state")
    if ok_state and state and state._s then
      if not state._s.compact_thinking_stopped then
        state._s.compact_thinking_stopped = true
        M.stop_thinking_and_print_compact()
      end
    else
      M.stop_thinking_and_print_compact()
    end
    local elapsed = timing.elapsed_sec()
    timing.clear_anim()
    return elapsed
  else
    local elapsed = timing.elapsed_sec()
    launch.kill_spinner()
    timing.clear_anim()
    return elapsed
  end
end

return M
