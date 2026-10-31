-- tests/golden_spec.lua — contrato visual por célula (fundo, texto, glifo).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local card = require("ui.card")
local block = require("ui.widgets.block")
local core = require("ui.core")
local misc = require("ui.misc")

local function read_lines(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local lines = {}
  for ln in f:lines() do lines[#lines + 1] = ln end
  f:close()
  return lines
end

-- Emulador mínimo: alimenta ANSI e devolve grid {fundo, texto, glifo} por célula.
local function grid_from(raw, tw)
  tw = tw or 80
  local grid = {}
  local row, col, fg, bg = 1, 1, nil, nil
  local function ensure(r)
    while #grid < r do
      local nr = {}
      for i = 1, tw do nr[i] = { fundo = nil, texto = nil, glifo = " " } end
      grid[#grid + 1] = nr
    end
  end
  local function put(ch)
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
      elseif n == 38 and parts[i + 1] == 5 then fg = parts[i + 2]; i = i + 2
      elseif n == 48 and parts[i + 1] == 5 then bg = parts[i + 2]; i = i + 2
      elseif n == 39 then fg = nil
      elseif n == 49 then bg = nil
      elseif n >= 40 and n <= 47 then bg = n - 40
      elseif n >= 100 and n <= 107 then bg = n
      elseif n >= 30 and n <= 37 then fg = n - 30
      elseif n == 1 or n == 2 or n == 22 then -- bold/dim: ignore for cell key
      end
      i = i + 1
    end
  end
  local i = 1
  raw = tostring(raw or "")
  while i <= #raw do
    local ch = raw:sub(i, i)
    if ch == "\27" then
      local seq = raw:sub(i):match("^(\27%[[0-9;:?]*[A-Za-z])")
      if seq then
        local params = seq:match("^\27%[([0-9;:?]*)") or ""
        local letter = seq:sub(-1)
        if letter == "m" then parse_sgr(params) end
        i = i + #seq
      else i = i + 1 end
    elseif ch == "\n" then row = row + 1; col = 1; i = i + 1
    elseif ch == "\r" then col = 1; i = i + 1
    else
      local ok, cp = pcall(utf8.codepoint, raw, i)
      if ok and cp then
        local g = utf8.char(cp)
        put(g)
        i = i + #g
      else put(ch); i = i + 1 end
    end
  end
  return grid
end

local function eq_cells(got_lines, gold_lines, name, tw)
  if not got_lines or not gold_lines then T(false, name .. " missing"); return end
  local got = grid_from(table.concat(got_lines, "\n"), tw)
  local gold = grid_from(table.concat(gold_lines, "\n"), tw)
  local max_r = math.max(#got, #gold)
  local diffs = 0
  for r = 1, max_r do
    for c = 1, (tw or 80) do
      local a = (got[r] and got[r][c]) or { fundo = nil, texto = nil, glifo = " " }
      local b = (gold[r] and gold[r][c]) or { fundo = nil, texto = nil, glifo = " " }
      if a.fundo ~= b.fundo or a.texto ~= b.texto or a.glifo ~= b.glifo then
        diffs = diffs + 1
        if diffs <= 5 then
          print(string.format("  cell %s r=%d c=%d got={%s,%s,%s} gold={%s,%s,%s}",
            name, r, c, tostring(a.fundo), tostring(a.texto), a.glifo,
            tostring(b.fundo), tostring(b.texto), b.glifo))
        end
      end
    end
  end
  T(diffs == 0, name .. (diffs == 0 and "" or (" diffs=" .. diffs)))
end

local BG, FG, DIM = "\27[48;5;236m", "\27[38;5;255m", "\27[38;5;245m"

for _, tw in ipairs({40, 80}) do
  local n, a = card.header_parts("bash", nil, tw)
  eq_cells({card.bg_row(BG, FG, "▶ ", FG, n .. a, tw)},
    read_lines(string.format("tests/golden/card_header_sem_arg_tw%d.txt", tw)),
    "card_header_sem_arg_tw" .. tw, tw)
  n, a = card.header_parts("bash", "ls -la", tw)
  eq_cells({card.bg_row(BG, FG, "▶ ", FG, n .. a, tw)},
    read_lines(string.format("tests/golden/card_header_com_arg_tw%d.txt", tw)),
    "card_header_com_arg_tw" .. tw, tw)
  local rows = card.body_rows({"linha um", "linha dois"}, tw)
  local body = {}
  for _, r in ipairs(rows) do body[#body + 1] = card.bg_row(BG, FG, r.prefix, r.dim and DIM or FG, r.text, tw) end
  eq_cells(body, read_lines(string.format("tests/golden/card_corpo_normal_tw%d.txt", tw)), "card_corpo_normal_tw" .. tw, tw)
  rows = card.body_rows({"antes \27[32mok\27[0m depois"}, tw)
  body = {}
  for _, r in ipairs(rows) do body[#body + 1] = card.bg_row(BG, FG, r.prefix, FG, r.text, tw) end
  eq_cells(body, read_lines(string.format("tests/golden/card_corpo_reset_tw%d.txt", tw)), "card_corpo_reset_tw" .. tw, tw)
  local many = {}
  for i = 1, 8 do many[i] = "L" .. i end
  rows = card.body_rows(many, tw)
  body = {}
  for _, r in ipairs(rows) do body[#body + 1] = card.bg_row(BG, FG, r.prefix, r.dim and DIM or FG, r.text, tw) end
  eq_cells(body, read_lines(string.format("tests/golden/card_corpo_maxbody_tw%d.txt", tw)), "card_corpo_maxbody_tw" .. tw, tw)
  rows = card.body_rows({"你好 🎉 test"}, tw)
  body = {}
  for _, r in ipairs(rows) do body[#body + 1] = card.bg_row(BG, FG, r.prefix, FG, r.text, tw) end
  eq_cells(body, read_lines(string.format("tests/golden/card_corpo_emoji_cjk_tw%d.txt", tw)), "card_corpo_emoji_cjk_tw" .. tw, tw)

  local b = block.new({borders = block.BORDERS.ALL, content_lines = {"conteudo"}})
  eq_cells(b:render({w = tw, h = 3}), read_lines(string.format("tests/golden/bloco_simples_tw%d.txt", tw)), "bloco_simples_tw" .. tw, tw)
  local bt = block.new({borders = block.BORDERS.ALL, border_type = block.TYPE.PLAIN,
    frame_bg = "\27[48;5;203m", frame_fg = "\27[38;5;52m", bg = "\27[48;5;52m", fg = "\27[38;5;231m",
    content_lines = {"Tentativa 1/5 — Sem resposta · aguardando 1s"}})
  eq_cells(bt:render({w = tw, h = nil}), read_lines(string.format("tests/golden/bloco_tentativa_tw%d.txt", tw)), "bloco_tentativa_tw" .. tw, tw)
  local be = block.new({borders = block.BORDERS.ALL, border_type = block.TYPE.PLAIN,
    frame_bg = "\27[48;5;203m", frame_fg = "\27[38;5;52m", bg = "\27[48;5;52m", fg = "\27[38;5;231m",
    content_lines = {"[recover] seq", "[ERRO] Falha após 5 tentativas"}})
  eq_cells(be:render({w = tw, h = nil}), read_lines(string.format("tests/golden/bloco_erro_tw%d.txt", tw)), "bloco_erro_tw" .. tw, tw)
  local bl = block.new({borders = block.BORDERS.ALL, content_lines = {string.rep("A", 80)}})
  eq_cells(bl:render({w = tw, h = nil}), read_lines(string.format("tests/golden/bloco_palavra_longa_tw%d.txt", tw)), "bloco_palavra_longa_tw" .. tw, tw)
end

for _, tw in ipairs({30, 40, 50, 80}) do
  for _, mode in ipairs({"vivo", "replay"}) do
    core.tw = function() return tw end
    local writes = {}
    local rw = io.write
    io.write = function(...) writes[#writes + 1] = table.concat({...}) end
    if mode == "vivo" then misc.footer(44124, 1000000, 1300, "17:55")
    else misc.footer(44124, 1000000, nil, "17:55")
    end
    io.write = rw
    local lines = {}
    for ln in (table.concat(writes) .. "\n"):gmatch("([^\n]*)\n") do
      if ln ~= "" then lines[#lines + 1] = ln end
    end
    eq_cells(lines, read_lines(string.format("tests/golden/rodape_%s_tw%d.txt", mode, tw)),
      "rodape_" .. mode .. "_tw" .. tw, tw)
  end
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
