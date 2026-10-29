-- tests/code_fence_messages_spec.lua — ``` vira card contínuo e ai_msg não destrói o pad.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- stubs de terminal
package.loaded["ui.core.terminal"] = function(core)
  function core.tw() return 40 end
  function core.th() return 24 end
  function core.invalidate_size() end
end
package.loaded["ui.core.texto"] = function(core)
  function core.strip(s)
    if not s:find("\27", 1, true) then return s end
    return (s:gsub("\27%[[0-9;]*m", ""))
  end
  function core.wlen(s) return #core.strip(s or "") end
  function core.wrap_para(para, w)
    local out, line = {}, ""
    for word in (para .. " "):gmatch("(%S+)%s*") do
      local candidate = line == "" and word or (line .. " " .. word)
      if core.wlen(candidate) > w then
        if line ~= "" then out[#out + 1] = line end
        line = word
      else
        line = candidate
      end
    end
    if line ~= "" then out[#out + 1] = line end
    if #out == 0 then out[#out + 1] = "" end
    return out
  end
  function core.render(text)
    return require("renderer").render(text)
  end
end

local core = require("ui.core")
local code = require("renderer.code_renderer")
local renderer = require("renderer")

local sample = [[Antes
```text
hello world line
segunda linha do bloco
```
Depois]]

local rendered = renderer.render(sample)
T(rendered:find("48;5;236", 1, true) ~= nil, "renderer emite fundo cinza")
T(code.is_code_card_line ~= nil, "expõe is_code_card_line")

local code_lines = 0
local destroyed = 0
for para in (rendered .. "\n"):gmatch("([^\n]*)\n") do
  if code.is_code_card_line(para) then
    code_lines = code_lines + 1
    -- pad: após o texto deve haver espaços antes do reset (fundo contínuo)
    local plain = para:gsub("\27%[[0-9;]*m", "")
    T(#plain >= 30, "linha de code card quase largura tw=40 (len=" .. #plain .. ")")
    -- se alguém fizer wrap_para + %S+, os espaços somem
    local words = {}
    for w in plain:gmatch("%S+") do words[#words + 1] = w end
    local rejoined = table.concat(words, " ")
    if #rejoined < #plain - 5 then
      -- esperado: plain tem espaços de pad; rejoined não
    end
  end
end
T(code_lines >= 3, "pelo menos fence+2 linhas de código (n=" .. code_lines .. ")")

-- Word-stream (%S+) colapsa o pad de espaços — o bug que messages deve evitar
local pad_destroyed = false
for para in (rendered .. "\n"):gmatch("([^\n]*)\n") do
  if code.is_code_card_line(para) then
    local plain = para:gsub("\27%[[0-9;]*m", "")
    local words = {}
    for w in plain:gmatch("%S+") do words[#words + 1] = w end
    if #table.concat(words, " ") < #plain - 3 then pad_destroyed = true end
  end
end
T(pad_destroyed, "word-stream destruiria o pad (messages escreve a linha íntegra)")

-- Caminho correto: escrever íntegro
local out = {}
local function capture(...)
  out[#out + 1] = table.concat({...})
end
local real_write = io.write
io.write = capture
-- messages precisa de core.c
local ok_msg, err = pcall(function()
  local messages = require("ui.messages")
  messages.ai_msg(sample)
end)
io.write = real_write
T(ok_msg, "ai_msg não erro (" .. tostring(err) .. ")")
local joined = table.concat(out)
T(joined:find("48;5;236", 1, true) ~= nil, "ai_msg preserva fundo do code card")
T(joined:find("hello world", 1, true) ~= nil, "ai_msg preserva texto do bloco")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
