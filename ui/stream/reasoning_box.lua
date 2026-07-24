-- reasoning_box.lua — Renderização collapsed e ciclo de vida da caixa de reasoning.
local core  = require("ui.core")
local state = require("ui.stream.state")
local ansi  = require("ui.stream.ansi_helpers")
local c = core.c
local M = {}

local function render_collapsed(visible_text, extra_lines)
  local s      = state._s
  local term_w = core.tw()
  local w      = term_w - 4
  local rendered = core.render_dim(visible_text)
  local total    = 0

  io.write(ansi.header_label(false, s.dots) .. "\n")
  total = total + 1

  for para in (rendered .. "\n"):gmatch("([^\n]*)\n") do
    local trimmed = para:match("^(.-)%s*$")
    if trimmed == "" then
      io.write(c.dim .. c.gray .. " │\27[K" .. c.reset .. "\n")
      total = total + 1
    else
      local wrapped = core.wrap_para(trimmed, w)
      for _, ln in ipairs(wrapped) do
        io.write(c.dim .. c.gray .. " │ " .. ln .. "\27[K" .. c.reset .. "\n")
      end
      total = total + #wrapped
    end
  end
  if extra_lines > 0 then
    io.write(c.dim .. c.gray .. " │ (+ " .. extra_lines .. " linhas)\27[K" .. c.reset .. "\n")
    total = total + 1
  end
  s.box_lines = total
  io.flush()
end

local function close_reasoning_box()
  local s    = state._s
  local text = s.reasoning
  if not text or text:match("^%s*$") then
    io.write("\n" .. c.dim .. c.gray .. " ╰" .. string.rep("─", 20) .. c.reset .. "\n\n")
    io.flush()
    return
  end

  if s.phase == "collapsed" then
    local lines_up = s.box_lines or s.reasoning_lines
    if lines_up > 0 then
      io.write("\27[s")
      io.write(string.format("\27[%dA\r", lines_up))
      io.write("\27[K")
      io.write(ansi.header_label(true))
      io.write("\27[u")
    end
    io.write(c.dim .. c.gray .. " ╰" .. string.rep("─", 20) .. "\27[K" .. c.reset .. "\n\n")
    io.flush()
    return
  end

  local total_lines = s.reasoning_lines
  if total_lines >= core.th() - 2 then
    io.write("\27[s")
    io.write(string.format("\27[%dA\r", total_lines))
    io.write("\27[K")
    io.write(ansi.header_label(true))
    io.write("\27[u")
    io.write("\n" .. c.dim .. c.gray .. " ╰" .. string.rep("─", 20) .. c.reset .. "\n\n")
    io.flush()
    return
  end

  local term_w = core.tw()
  io.write(string.format("\27[%dA", total_lines))
  io.write("\r\27[J")
  local rendered = core.render_dim(text)
  local w = term_w - 4
  io.write(ansi.header_label(true) .. "\n")
  for para in (rendered .. "\n"):gmatch("([^\n]*)\n") do
    local trimmed = para:match("^(.-)%s*$")
    if trimmed == "" then
      io.write(c.dim .. c.gray .. " │\27[K" .. c.reset .. "\n")
    else
      core.print_reasoning_line(trimmed, w)
    end
  end
  io.write(c.dim .. c.gray .. " ╰" .. string.rep("─", 20) .. "\27[K" .. c.reset .. "\n\n")
  io.flush()
end

M.render_collapsed    = render_collapsed
M.close_reasoning_box = close_reasoning_box
return M
