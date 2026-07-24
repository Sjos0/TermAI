local core = require("ui.core")
local c = core.c
local M = {}

function M.header(m, session_id)
  io.write(c.cls)
  local f = io.open(core.ROOT .. "/banner.txt", "r")
  if f then
    local lines = {}
    local max_w = 0
    for line in f:lines() do
      table.insert(lines, line)
      if #line > max_w then max_w = #line end
    end
    f:close()

    local term_w = core.tw()
    local box_w = max_w + 4
    local pad_left = math.max(0, math.floor((term_w - box_w) / 2))
    local margin = string.rep(" ", pad_left)

    io.write(margin .. c.dim .. c.white .. "╭" .. string.rep("─", box_w - 2) .. "╮\n" .. c.reset)
    for i, line in ipairs(lines) do
      local ratio = (#lines > 1) and ((i - 1) / (#lines - 1)) or 0
      local r = math.floor(60  + (0   - 60)  * ratio)
      local g = math.floor(180 + (40  - 180) * ratio)
      local b = math.floor(255 + (150 - 255) * ratio)
      local color = string.format("\27[38;2;%d;%d;%dm", r, g, b)
      local padded = line .. string.rep(" ", max_w - #line)
      io.write(margin .. c.dim .. c.white .. "│ " .. c.reset
            .. color .. c.bold .. padded .. c.reset
            .. c.dim .. c.white .. " │\n" .. c.reset)
    end
    io.write(margin .. c.dim .. c.white .. "╰" .. string.rep("─", box_w - 2) .. "╯\n" .. c.reset)
  end

  local pwd = os.getenv("PWD") or ""
  pwd = pwd:gsub(os.getenv("HOME") or "", "~")
  local spaces = core.tw() - #pwd - #m
  if spaces < 1 then spaces = 1 end
  io.write(c.green .. pwd .. string.rep(" ", spaces) .. c.cyan .. m .. c.reset .. "\n")

  -- ID da sessão ativa (discreta, logo abaixo do modelo)
  if session_id then
    io.write(c.dim .. c.gray .. " ⬡ " .. session_id .. c.reset .. "\n\n")
  else
    io.write("\n")
  end

  io.write(c.dim .. c.white .. " Dicas para começar:\n" .. c.reset)
  io.write(c.gray .. " 1. Faça perguntas, edite arquivos ou rode comandos.\n")
  io.write(" 2. Seja específico para que eu possa usar minhas ferramentas nativas.\n")
  io.write(" 3. Seus arquivos em workspace/ moldam a minha identidade e memória.\n" .. c.reset .. "\n")
end

function M.erase_input(raw)
  local w = core.tw()
  local linhas = math.max(1, math.ceil((2 + #raw) / w))
  for _ = 1, linhas do io.write("\27[1A\27[2K") end
end

return M
