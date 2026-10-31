-- tests/bloco_erro_cores_spec.lua — #278: cores do bloco de erro por célula.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local function novo_emulador(tw, th)
  tw = tw or 40; th = th or 10
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
        local seq = raw:sub(i):match("^(\27%[([0-9;]*)([A-Za-z]))")
        if seq then
          local params = seq:match("^\27%[([0-9;]*)") or ""
          local letter = seq:sub(-1)
          if letter == "m" then parse_sgr(params) end
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
        else
          put_char(c); i = i + 1
        end
      end
    end
  end
  local function celula(r, c) ensure(r); return grid[r][c] end
  return { feed = feed, celula = celula }
end

local block = require("ui.widgets.block")

for _, tw in ipairs({ 40, 80 }) do
  local b = block.new({
    borders = block.BORDERS.ALL,
    frame_bg = "\27[48;5;203m",
    frame_fg = "\27[38;5;52m",
    bg = "\27[48;5;52m",
    fg = "\27[38;5;231m",
    content_lines = { "[ERRO] falha" },
  })
  local lines = b:render({ w = tw, h = nil })
  local em = novo_emulador(tw, #lines + 2)
  for _, ln in ipairs(lines) do em.feed(ln .. "\n") end
  -- topo: fundo 203
  local bad_frame, bad_inner, bad_fg = 0, 0, 0
  for c = 1, tw do
    if em.celula(1, c).fundo ~= 203 then bad_frame = bad_frame + 1 end
  end
  T(bad_frame == 0, "tw=" .. tw .. " topo frame_bg 203 (bad=" .. bad_frame .. ")")
  -- interior linha 2: fundo 52 (células internas 2..tw-1)
  for c = 2, tw - 1 do
    local cell = em.celula(2, c)
    if cell.fundo ~= 52 then bad_inner = bad_inner + 1 end
  end
  T(bad_inner == 0, "tw=" .. tw .. " interior bg 52 (bad=" .. bad_inner .. ")")
  -- glifos de canto topo
  local tl = em.celula(1, 1)
  T(tl.glifo == "┌" or tl.glifo ~= " ", "tw=" .. tw .. " canto topo presente")
  print(string.format("CAPTURA tw=%d linhas=%d topo_fg=%s", tw, #lines, tostring(em.celula(1,1).texto)))
end

-- regressão sem frame_*: comportamento legado com bg
do
  local b = block.new({ borders = block.BORDERS.ALL, bg = "\27[48;5;52m", content_lines = { "x" } })
  local lines = b:render({ w = 20, h = 3 })
  T(#lines == 3, "regressao sem frame: 3 linhas")
  local em = novo_emulador(20, 5)
  for _, ln in ipairs(lines) do em.feed(ln .. "\n") end
  T(em.celula(1, 1).fundo == 52, "sem frame_bg: topo usa bg 52")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
