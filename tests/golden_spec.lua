-- tests/golden_spec.lua — compara saída atual com goldens (contrato visual).
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
  for ln in f:lines() do lines[#lines+1] = ln end
  f:close()
  return lines
end

local function eq_lines(a, b, name)
  if not a or not b then T(false, name .. " missing"); return end
  if #a ~= #b then
    T(false, name .. " linhas " .. #a .. " vs golden " .. #b)
    return
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      T(false, name .. " dif linha " .. i)
      print("  got: " .. a[i]:gsub("\27", "\\e"):sub(1, 80))
      print("  gold:" .. b[i]:gsub("\27", "\\e"):sub(1, 80))
      return
    end
  end
  T(true, name)
end

local BG, FG, DIM = "\27[48;5;236m", "\27[38;5;255m", "\27[38;5;245m"

for _, tw in ipairs({40, 80}) do
  local n, a = card.header_parts("bash", nil, tw)
  eq_lines({card.bg_row(BG, FG, "▶ ", FG, n .. a, tw)},
    read_lines(string.format("tests/golden/card_header_sem_arg_tw%d.txt", tw)),
    "card_header_sem_arg_tw" .. tw)
  n, a = card.header_parts("bash", "ls -la", tw)
  eq_lines({card.bg_row(BG, FG, "▶ ", FG, n .. a, tw)},
    read_lines(string.format("tests/golden/card_header_com_arg_tw%d.txt", tw)),
    "card_header_com_arg_tw" .. tw)
  local rows = card.body_rows({"linha um", "linha dois"}, tw)
  local body = {}
  for _, r in ipairs(rows) do body[#body+1] = card.bg_row(BG, FG, r.prefix, r.dim and DIM or FG, r.text, tw) end
  eq_lines(body, read_lines(string.format("tests/golden/card_corpo_normal_tw%d.txt", tw)), "card_corpo_normal_tw" .. tw)
  rows = card.body_rows({"antes \27[32mok\27[0m depois"}, tw)
  body = {}
  for _, r in ipairs(rows) do body[#body+1] = card.bg_row(BG, FG, r.prefix, FG, r.text, tw) end
  eq_lines(body, read_lines(string.format("tests/golden/card_corpo_reset_tw%d.txt", tw)), "card_corpo_reset_tw" .. tw)
  local many = {}
  for i=1,8 do many[i]="L"..i end
  rows = card.body_rows(many, tw)
  body = {}
  for _, r in ipairs(rows) do body[#body+1] = card.bg_row(BG, FG, r.prefix, r.dim and DIM or FG, r.text, tw) end
  eq_lines(body, read_lines(string.format("tests/golden/card_corpo_maxbody_tw%d.txt", tw)), "card_corpo_maxbody_tw" .. tw)
  rows = card.body_rows({"你好 🎉 test"}, tw)
  body = {}
  for _, r in ipairs(rows) do body[#body+1] = card.bg_row(BG, FG, r.prefix, FG, r.text, tw) end
  eq_lines(body, read_lines(string.format("tests/golden/card_corpo_emoji_cjk_tw%d.txt", tw)), "card_corpo_emoji_cjk_tw" .. tw)

  local b = block.new({borders=block.BORDERS.ALL, content_lines={"conteudo"}})
  eq_lines(b:render({w=tw, h=3}), read_lines(string.format("tests/golden/bloco_simples_tw%d.txt", tw)), "bloco_simples_tw" .. tw)
  local bt = block.new({borders=block.BORDERS.ALL, border_type=block.TYPE.PLAIN,
    frame_bg="\27[48;5;203m", frame_fg="\27[38;5;52m", bg="\27[48;5;52m", fg="\27[38;5;231m",
    content_lines={"Tentativa 1/5 — Sem resposta · aguardando 1s"}})
  eq_lines(bt:render({w=tw, h=nil}), read_lines(string.format("tests/golden/bloco_tentativa_tw%d.txt", tw)), "bloco_tentativa_tw" .. tw)
  local be = block.new({borders=block.BORDERS.ALL, border_type=block.TYPE.PLAIN,
    frame_bg="\27[48;5;203m", frame_fg="\27[38;5;52m", bg="\27[48;5;52m", fg="\27[38;5;231m",
    content_lines={"[recover] seq", "[ERRO] Falha após 5 tentativas"}})
  eq_lines(be:render({w=tw, h=nil}), read_lines(string.format("tests/golden/bloco_erro_tw%d.txt", tw)), "bloco_erro_tw" .. tw)
  local bl = block.new({borders=block.BORDERS.ALL, content_lines={string.rep("A", 80)}})
  eq_lines(bl:render({w=tw, h=nil}), read_lines(string.format("tests/golden/bloco_palavra_longa_tw%d.txt", tw)), "bloco_palavra_longa_tw" .. tw)
end

for _, tw in ipairs({30,40,50,80}) do
  for _, mode in ipairs({"vivo", "replay"}) do
    core.tw = function() return tw end
    local writes = {}
    local rw = io.write
    io.write = function(...) writes[#writes+1]=table.concat({...}) end
    if mode == "vivo" then misc.footer(44124, 1000000, 1300, "17:55")
    else misc.footer(44124, 1000000, nil, "17:55") end
    io.write = rw
    local lines = {}
    for ln in (table.concat(writes).."\n"):gmatch("([^\n]*)\n") do
      if ln ~= "" then lines[#lines+1]=ln end
    end
    eq_lines(lines, read_lines(string.format("tests/golden/rodape_%s_tw%d.txt", mode, tw)),
      "rodape_" .. mode .. "_tw" .. tw)
  end
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
