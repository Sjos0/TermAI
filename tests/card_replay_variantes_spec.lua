-- tests/card_replay_variantes_spec.lua — #293: card replay sem buracos (caminho real).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- Emulador por célula (independente)
local function novo_emulador(tw, th)
  tw = tw or 80; th = th or 40
  local grid = {}
  for r = 1, th do
    grid[r] = {}
    for c = 1, tw do grid[r][c] = { fundo = nil, texto = nil, glifo = " " } end
  end
  local row, col, fg, bg = 1, 1, nil, nil
  local function ensure(r)
    while #grid < r do
      local nr = {}
      for i = 1, tw do nr[i] = { fundo = nil, texto = nil, glifo = " " } end
      grid[#grid + 1] = nr
    end
  end
  local function put_char(ch)
    if col > tw then row = row + 1; col = 1 end
    ensure(row)
    grid[row][col] = { fundo = bg, texto = fg, glifo = ch }
    col = col + 1
  end
  local function parse_sgr(params)
    if params == "" or params == "0" then fg, bg = nil, nil; return end
    local parts = {}
    for p in (params .. ";"):gmatch("([^;]*);") do parts[#parts + 1] = tonumber(p) or 0 end
    local i = 1
    while i <= #parts do
      local n = parts[i]
      if n == 0 then fg, bg = nil, nil
      elseif n == 38 and parts[i+1] == 5 then fg = parts[i+2]; i = i + 2
      elseif n == 48 and parts[i+1] == 5 then bg = parts[i+2]; i = i + 2
      elseif n == 39 then fg = nil
      elseif n == 49 then bg = nil
      elseif n >= 40 and n <= 47 then bg = n - 40 -- basic
      elseif n >= 100 and n <= 107 then bg = n
      elseif n >= 30 and n <= 37 then fg = n - 30
      end
      i = i + 1
    end
  end
  local function feed(raw)
    raw = tostring(raw or "")
    local i = 1
    while i <= #raw do
      local c = raw:sub(i, i)
      if c == "\27" then
        local seq = raw:sub(i):match("^(\27%[([0-9;:?]*)([A-Za-z]))")
        if seq then
          local params = seq:match("^\27%[([0-9;:?]*)") or ""
          local letter = seq:sub(-1)
          if letter == "m" then parse_sgr(params)
          elseif letter == "K" or letter == "J" then
            -- erase: clear cells but bg state stays as SGR says
          end
          i = i + #seq
        else i = i + 1 end
      elseif c == "\n" then row = row + 1; col = 1; i = i + 1
      elseif c == "\r" then col = 1; i = i + 1
      else
        local ok, cp = pcall(utf8.codepoint, raw, i)
        if ok and cp then
          local ch = utf8.char(cp)
          put_char(ch)
          i = i + #ch
        else put_char(c); i = i + 1 end
      end
    end
  end
  local function celula(r, c) ensure(r); return grid[r][c] end
  return { feed = feed, celula = celula, rows = function() return row end }
end

local core = require("ui.core")
core.tw = function() return 50 end
local c = core.c
local CARD_BG = 234 -- c.bg = 48;5;234

local variants = {
  "\27[0m", "\27[m", "\27[49m", "\27[40m", "\27[41m",
  "\27[48;5;196m", "\27[1;31;42m", "\27[100m",
  "\27[48;2;255;0;0m", "\27[K", "\27[J",
}

local out_lines = {}
for i, v in ipairs(variants) do
  out_lines[#out_lines + 1] = string.format("v%d:%sX", i, v)
end
local out = table.concat(out_lines, "\n")

local writes = {}
local rw = io.write
io.write = function(...) writes[#writes + 1] = table.concat({...}) end

local executor = require("ui.tools_init.executor")
executor.tool_replay("Exec (echo variants)", out, true)

io.write = rw
local captured = table.concat(writes)

-- Feed into emulator
local em = novo_emulador(50, 30)
em.feed(captured)

local bad = 0
local max_r = em.rows()
for r = 1, math.min(max_r, 20) do
  for col = 1, 50 do
    local cell = em.celula(r, col)
    -- only check non-space cells or cells that should be card body
    if cell.glifo ~= " " or cell.fundo ~= nil then
      if cell.fundo ~= CARD_BG and cell.fundo ~= nil then
        -- header dots may use other colors on borders? card body should be 234
        -- allow nil only outside; body pads should have 234
      end
    end
    -- Strict: every cell that has a glifo from the card row should have fundo 234
    if cell.glifo ~= " " and cell.fundo ~= CARD_BG then
      bad = bad + 1
    end
  end
end

-- Also check that after each variant token X, surrounding has 234
-- Simpler: count cells with fundo != 234 among written content rows
local bad_bg = 0
local total_written = 0
for r = 1, math.min(max_r, 15) do
  for col = 1, 50 do
    local cell = em.celula(r, col)
    if cell.glifo ~= " " then
      total_written = total_written + 1
      if cell.fundo ~= CARD_BG then
        bad_bg = bad_bg + 1
      end
    end
  end
end

T(total_written > 10, "capturou saida do tool_replay (cells=" .. total_written .. ")")
T(bad_bg == 0, "nenhuma celula com fundo != 234 (bad=" .. bad_bg .. " / " .. total_written .. ")")

-- List sample of bad for debug
if bad_bg > 0 then
  for r = 1, math.min(max_r, 12) do
    for col = 1, 50 do
      local cell = em.celula(r, col)
      if cell.glifo ~= " " and cell.fundo ~= CARD_BG then
        print(string.format("  bad r=%d c=%d fundo=%s glifo=%s", r, col, tostring(cell.fundo), cell.glifo))
        bad_bg = bad_bg - 1
        if bad_bg <= 0 then break end
      end
    end
  end
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
