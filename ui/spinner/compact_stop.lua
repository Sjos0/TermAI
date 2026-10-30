-- ui/spinner/compact_stop.lua — parada do thinking (#226, #268)
local launch = require("ui.spinner.launch")
local timing = require("ui.spinner.timing")
local M = {}

local function get_thinking_mode()
  local ok, config_mod = pcall(require, "config")
  if ok and config_mod then
    local ok_val, val = pcall(config_mod.get, "agents.defaults.thinking_mode")
    if ok_val and val then return val end
  end
  return "expanded"
end

function M.stop_thinking_and_print_compact()
  if not timing.get_anim_start() then return end
  local elapsed_ms = timing.elapsed_ms()
  launch.kill_spinner()
  timing.clear_anim()

  -- #268: enquanto o card de retry está ativo, não escrever \n.
  -- A quebra deslocava o cursor e o erase() de retry só apagava a parte de baixo.
  local ok_r, retry = pcall(require, "ui.spinner.retry")
  if ok_r and retry and retry.is_active and retry.is_active() then
    io.write("\r\27[K")
    io.flush()
    return
  end

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

--- Para o thinking conforme o modo ativo; retorna elapsed em MILISSEGUNDOS.
function M.stop_thinking()
  local tmode = get_thinking_mode()
  if tmode == "compact" then
    -- Captura elapsed ANTES de stop_thinking_and_print_compact(), pois essa
    -- função já chama timing.clear_anim() por dentro (zera _anim_start).
    local elapsed = timing.elapsed_total_ms()
    local ok_state, state = pcall(require, "ui.stream.state")
    if ok_state and state and state._s then
      if not state._s.compact_thinking_stopped then
        state._s.compact_thinking_stopped = true
        M.stop_thinking_and_print_compact()
      end
    else
      M.stop_thinking_and_print_compact()
    end
    timing.clear_anim()
    return elapsed
  else
    local elapsed = timing.elapsed_total_ms()
    launch.kill_spinner()
    timing.clear_anim()
    return elapsed
  end
end

return M
