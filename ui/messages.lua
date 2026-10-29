local core = require("ui.core")
local c = core.c
local M = {}

local function is_code_card_line(line)
  local ok, code = pcall(require, "renderer.code_renderer")
  if ok and code and code.is_code_card_line then
    return code.is_code_card_line(line)
  end
  return type(line) == "string" and line:find("\27[48;5;", 1, true) ~= nil
end

function M.user_msg(t, pasted_texts)
  if pasted_texts then
    for idx, raw_text in pairs(pasted_texts) do
      local count = 0
      for _ in (raw_text .. "\n"):gmatch("([^\n]*)\n") do
        count = count + 1
      end
      t = t:gsub("%[pasted_text#" .. idx .. "[^%]]*%]",
        "\27[38;5;220m[pasted_text#" .. idx .. " + " .. count .. " linha(s)]\27[39m")
    end
  end

  t = core.render(t)
  local w = core.tw()
  local first = true
  for para in (t .. "\n"):gmatch("([^\n]*)\n") do
    if is_code_card_line(para) then
      -- Já veio do renderer com fundo contínuo — não trim, não wrap.
      io.write(para .. "\n")
      first = false
    else
      local trimmed = para:match("^%s*(.-)%s*$") or ""
      if trimmed == "" then
        if not first then io.write("\n") end
      else
        for i, ln in ipairs(core.wrap_para(trimmed, math.max(8, w - 4))) do
          if first and i == 1 then
            local str = "❯ " .. ln
            local pad = string.rep(" ", math.max(0, w - core.wlen(str)))
            io.write(c.bg_user .. c.bold .. "\27[38;5;39m❯\27[0m" .. c.bg_user
              .. " " .. ln .. pad .. c.reset .. "\n")
            first = false
          else
            local str = "  " .. ln
            local pad = string.rep(" ", math.max(0, w - core.wlen(str)))
            io.write(c.bg_user .. str .. pad .. c.reset .. "\n")
            first = false
          end
        end
      end
    end
  end
  io.write("\n")
end

function M.ai_msg(t)
  t = core.render(t)
  t = t:gsub("\n\n\n+", "\n\n")
  local w = core.tw() - 4
  local first_line = true
  local blank_streak = 0
  for para in (t .. "\n"):gmatch("([^\n]*)\n") do
    if is_code_card_line(para) then
      blank_streak = 0
      if first_line then
        io.write(c.white .. "⬤\n")
        first_line = false
      end
      io.write(para .. "\n")
    else
      local trimmed = para:match("^%s*(.-)%s*$")
      if trimmed == "" then
        blank_streak = blank_streak + 1
        if blank_streak <= 1 then io.write("\n") end
      else
        blank_streak = 0
        local lines = core.wrap_para(trimmed, w)
        for i, ln in ipairs(lines) do
          if first_line and i == 1 then
            io.write(c.white .. "⬤ " .. ln .. "\n")
            first_line = false
          else
            io.write(" " .. ln .. "\n")
          end
        end
      end
    end
  end
  io.write("\n"); io.flush()
end

function M.ai_msg_stream(t)
  t = core.render(t)
  local w = core.tw() - 4
  local first_line = true
  for para in (t .. "\n"):gmatch("([^\n]*)\n") do
    if is_code_card_line(para) then
      -- Card de código: escrever a linha inteira (fundo + pad). Sem word-stream.
      if first_line then
        io.write(c.white .. "⬤\n")
        first_line = false
      end
      io.write(para .. "\n")
      io.flush()
    else
      local trimmed = para:match("^%s*(.-)%s*$")
      if trimmed == "" then
        io.write("\n")
      else
        local lines = core.wrap_para(trimmed, w)
        for i, ln in ipairs(lines) do
          if first_line and i == 1 then
            io.write(c.white .. "⬤ " .. c.reset)
            first_line = false
          else
            io.write(" ")
          end
          local word_count = 0
          for word in ln:gmatch("%S+%s*") do
            io.write(word)
            io.flush()
            word_count = word_count + 1
            if word_count % 2 == 0 then os.execute("sleep 0.02") end
          end
          io.write("\n")
        end
      end
    end
  end
  io.write("\n"); io.flush()
end

return M
