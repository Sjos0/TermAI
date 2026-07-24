local core = require("ui.core")
local c = core.c
local M = {}

function M.user_msg(t, pasted_texts)
  -- Colapsa os placeholders do pasted_text com metadados de linhas reais usando regex seguro
  if pasted_texts then
    for idx, raw_text in pairs(pasted_texts) do
      local count = 0
      for _ in (raw_text .. "\n"):gmatch("([^\n]*)\n") do
        count = count + 1
      end
      t = t:gsub("%[pasted_text#" .. idx .. "[^%]]*%]", "\27[38;5;220m[pasted_text#" .. idx .. " + " .. count .. " linha(s)]\27[39m")
    end
  end

  t = core.render(t)
  local w = core.tw()
  for i, ln in ipairs(core.wrap_para(t, w - 4)) do
    if i == 1 then
      local str = "❯ " .. ln
      local pad = string.rep(" ", math.max(0, w - core.wlen(str)))
      io.write(c.bg_user .. c.bold .. "\27[38;5;39m❯\27[0m" .. c.bg_user .. " " .. ln .. pad .. c.reset .. "\n")
    else
      local str = "  " .. ln
      local pad = string.rep(" ", math.max(0, w - core.wlen(str)))
      io.write(c.bg_user .. str .. pad .. c.reset .. "\n")
    end
  end
  io.write("\n")
end

function M.ai_msg(t)
  t = core.render(t)
  local w = core.tw() - 4
  local first_line = true
  for para in (t .. "\n"):gmatch("([^\n]*)\n") do
    local trimmed = para:match("^%s*(.-)%s*$")
    if trimmed == "" then
      io.write("\n")
    else
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
  io.write("\n"); io.flush()
end

function M.ai_msg_stream(t)
  t = core.render(t)
  local w = core.tw() - 4
  local first_line = true
  for para in (t .. "\n"):gmatch("([^\n]*)\n") do
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
  io.write("\n"); io.flush()
end

return M
