-- ui/spinner/timing.lua — formatação de duração e cálculo de elapsed.
local M = {}

local _anim_start         = nil
local _start_ms           = nil
local _reasoning_start_ms = nil

--- Retorna timestamp em milissegundos (date +%s%3N ou fallback os.time).
function M.get_ms_time()
  local f = io.popen("date +%s%3N")
  if f then
    local s = f:read("*l")
    f:close()
    local val = tonumber(s)
    if val then return val end
  end
  return os.time() * 1000
end

--- Formata duração em ms para string legível (ex: "320ms", "1.2seg", "2min 5seg").
function M.format_duration(ms)
  if ms < 1000 then
    return string.format("%dms", ms)
  elseif ms < 60000 then
    local sec = ms / 1000
    local integer, fractional = math.modf(sec)
    if fractional >= 0.1 then
      return string.format("%.1fseg", sec)
    else
      return string.format("%dseg", integer)
    end
  else
    local total_sec = math.floor(ms / 1000)
    local min = math.floor(total_sec / 60)
    local sec = total_sec % 60
    if sec > 0 then
      return string.format("%dmin %dseg", min, sec)
    else
      return string.format("%dmin", min)
    end
  end
end

--- Inicializa timers de animação (chamado no start/restart).
function M.reset_timers()
  _anim_start         = os.time()
  _start_ms           = M.get_ms_time()
  _reasoning_start_ms = nil
end

--- Marca o instante em que o reasoning começou (primeiro token).
function M.mark_reasoning()
  _reasoning_start_ms = M.get_ms_time()
end

function M.get_anim_start()
  return _anim_start
end

function M.set_anim_start(v)
  _anim_start = v
end

function M.clear_anim()
  _anim_start = nil
end

function M.get_start_ms()
  return _start_ms
end

function M.get_reasoning_start_ms()
  return _reasoning_start_ms
end

--- Elapsed em ms a partir do início do reasoning (ou do ciclo se não houve).
function M.elapsed_ms()
  local base_ms = _reasoning_start_ms or _start_ms or M.get_ms_time()
  return M.get_ms_time() - base_ms
end

--- Elapsed em segundos a partir de _anim_start (modo expanded).
function M.elapsed_sec()
  return os.time() - (_anim_start or os.time())
end

return M
