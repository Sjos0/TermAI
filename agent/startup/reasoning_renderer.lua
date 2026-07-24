-- reasoning_renderer.lua — Renderiza o reasoning do modelo em um box ANSI no replay.
-- Função pura: depende apenas de ui.core (tw, render_dim, wrap_para) e suas cores.
-- v2: colapsa como no live (ui/stream/reasoning_box.lua) — antes mostrava o
-- texto INTEIRO sempre, diferente da experiência ao vivo (que corta com
-- "(+ N linhas)"). Replay agora usa o mesmo padrão visual compacto.
local core = require("ui.core")
local c    = core.c
local M = {}

local MAX_REASONING_LINES = 6

local function show_reasoning_box(reasoning)
  if not reasoning or reasoning:match("^%s*$") then return end
  local DARK_GREEN = "\27[38;5;71m"
  local tw = core.tw()
  local w  = tw - 4
  io.write(c.dim .. c.gray .. " ╭─ Pensamento Concluído "
    .. DARK_GREEN .. "✓" .. c.reset .. "\n")
  local rendered = core.render_dim(reasoning)

  -- v2: junta todas as linhas primeiro pra poder colapsar como no live.
  local all_lines = {}
  for para in (rendered .. "\n"):gmatch("([^\n]*)\n") do
    local trimmed = para:match("^(.-)%s*$")
    if trimmed == "" then
      all_lines[#all_lines + 1] = ""
    else
      local wrapped = core.wrap_para(trimmed, w)
      for _, ln in ipairs(wrapped) do
        all_lines[#all_lines + 1] = ln
      end
    end
  end

  local visible = math.min(#all_lines, MAX_REASONING_LINES)
  for i = 1, visible do
    if all_lines[i] == "" then
      io.write(c.dim .. c.gray .. " │" .. c.reset .. "\n")
    else
      io.write(c.dim .. c.gray .. " │ " .. all_lines[i] .. c.reset .. "\n")
    end
  end
  if #all_lines > MAX_REASONING_LINES then
    io.write(c.dim .. c.gray .. " │ (+ "
      .. (#all_lines - MAX_REASONING_LINES) .. " linhas)" .. c.reset .. "\n")
  end

  io.write(c.dim .. c.gray .. " ╰" .. string.rep("─", 20) .. c.reset .. "\n\n")
  io.flush()
end
M.show_reasoning_box = show_reasoning_box
return M
