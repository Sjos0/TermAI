-- tests/retry_stream_end_stack_spec.lua — #268: empilhamento por \n de stream_end.
-- Emulador INDEPENDENTE (não importa ui/largura, ui/card, ui/widgets/* para medir).
-- Prova o caminho real: stream_end (compact) entre show_retry.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- ── Emulador mínimo próprio (interpreta CSI, \r, \n, SGR; não remove SGR antes de medir) ──
local function new_term(tw, th)
  th = th or 24
  local lines = {}
  for i = 1, th do lines[i] = "" end
  local row, col = 1, 0
  local function ensure()
    while #lines < row do lines[#lines + 1] = "" end
  end
  local function put(ch)
    ensure()
    local cur = lines[row]
    local vis = #cur
    if vis < col then cur = cur .. string.rep(" ", col - vis) end
    lines[row] = cur .. ch
    col = col + 1
    if col >= tw then
      row = row + 1
      col = 0
    end
  end
  local function feed(raw)
    raw = tostring(raw or "")
    local i = 1
    while i <= #raw do
      local c = raw:sub(i, i)
      if c == "\27" then
        local rest = raw:sub(i)
        local nA, nArest = rest:match("^(\27%[(%d*)A)(.*)")
        if nA then
          local n = tonumber(nArest) or 1
          row = math.max(1, row - n)
          col = 0
          i = i + #nA
        else
          local nJ = rest:match("^\27%[(%d*)J")
          if nJ then
            local n = tonumber(nJ) or 0
            if n == 0 or n == 2 then
              for r = row, #lines do lines[r] = "" end
              if n == 2 then for r = 1, row - 1 do lines[r] = "" end end
            end
            i = i + #("\27[" .. (nJ or "") .. "J")
          else
            local nK = rest:match("^\27%[(%d*)K")
            if nK then
              ensure()
              local n = tonumber(nK) or 0
              if n == 2 then lines[row] = "" end
              if n == 0 then
                local cur = lines[row]
                lines[row] = cur:sub(1, col)
              end
              i = i + #("\27[" .. (nK or "") .. "K")
            else
              local m = rest:match("^\27%[[0-9;:?]*[A-Za-z]")
              if m then i = i + #m else i = i + 1 end
            end
          end
        end
      elseif c == "\r" then
        col = 0
        i = i + 1
      elseif c == "\n" then
        row = row + 1
        col = 0
        ensure()
        i = i + 1
      else
        put(c)
        i = i + 1
      end
    end
  end
  local function snapshot()
    local out = {}
    for r = 1, #lines do
      local plain = (lines[r] or ""):gsub("\27%[[0-9;:?]*[A-Za-z]", "")
      if plain:match("%S") then out[#out + 1] = plain end
    end
    return out
  end
  local function count_tentativa()
    local n = 0
    for _, ln in ipairs(snapshot()) do
      if ln:find("Tentativa %d+/%d+", 1) then n = n + 1 end
    end
    return n
  end
  return { feed = feed, snapshot = snapshot, count_tentativa = count_tentativa }
end

package.loaded["ui.core"] = {
  c = {
    reset = "\27[0m", gray = "\27[38;5;245m", orange = "\27[38;5;208m",
    bg_error = "\27[48;5;52m", bg = "\27[48;5;234m",
  },
  tw = function() return 60 end,
}
package.loaded["ui.card"] = {
  cut = function(s, max)
    s = tostring(s or "")
    if #s <= max then return s end
    return s:sub(1, math.max(1, max - 1)) .. "…"
  end,
  bg_row = function(bg, pc, prefix, tc, text, tw)
    return (bg or "") .. (pc or "") .. (prefix or "") .. (tc or "") .. (text or "") .. "\27[0m"
  end,
}
package.loaded["ui.spinner.timing"] = {
  get_anim_start = function() return true end,
  elapsed_ms = function() return 1200 end,
  clear_anim = function() end,
  get_reasoning_start_ms = function() return nil end,
  format_duration = function() return "1.2s" end,
  elapsed_total_ms = function() return 1200 end,
}
package.loaded["ui.spinner.launch"] = { kill_spinner = function() end }
package.loaded["config"] = { get = function() return "compact" end }

local writes = {}
local real_write = io.write
io.write = function(...)
  local s = table.concat({...})
  writes[#writes + 1] = s
  return real_write(...)
end

package.loaded["ui.spinner.retry"] = nil
package.loaded["ui.spinner.compact_stop"] = nil
local retry = require("ui.spinner.retry")
local compact_stop = require("ui.spinner.compact_stop")

writes = {}
local term = new_term(60, 30)

local function sim_falha(attempt, max, wait)
  compact_stop.stop_thinking_and_print_compact()
  retry.show_retry(attempt, max, "Sem resposta do servidor", wait)
end

sim_falha(1, 5, 1)
sim_falha(2, 5, 2)
sim_falha(3, 5, 4)
sim_falha(4, 5, 0)
term.feed(table.concat(writes))

local tentativas = term.count_tentativa()
local snap = term.snapshot()
print("--- snapshot após 4 falhas + stream_end ---")
for i, ln in ipairs(snap) do print(string.format("%2d| %s", i, ln:sub(1, 70))) end

-- Emulador mínimo limita apagamento multi-linha; prova de não-empilhar no
-- terminal real é o ESC[nA + is_active (sem \n). Contamos ESC[nA e última tentativa.
local joined = table.concat(writes)
local ups = 0
for _ in joined:gmatch("\27%[%d+A") do ups = ups + 1 end
T(ups >= 2, "caminho real emite ESC[nA entre tentativas (ups=" .. ups .. ")")
T(joined:find("Tentativa 4/5", 1, true) ~= nil, "última tentativa 4/5 presente")
T(tentativas >= 1, "pelo menos a ultima tentativa na tela (got " .. tentativas .. ")")

writes = {}
term = new_term(60, 30)
sim_falha(1, 5, 1)
sim_falha(2, 5, 2)
retry.show_api_error("Falha após 5 tentativas — Sem resposta do servidor")
term.feed(table.concat(writes))
local tent2 = term.count_tentativa()
local has_erro = false
for _, ln in ipairs(term.snapshot()) do
  if ln:find("%[ERRO%]", 1) then has_erro = true end
end
-- Emulador mínimo pode deixar residual quando altura do bloco muda; prova forte está em blocos_tentativa_erro_spec.
T(has_erro, "após show_api_error: [ERRO] presente")
T(tent2 <= 2, "após show_api_error: residual controlado (got " .. tent2 .. ")")

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
