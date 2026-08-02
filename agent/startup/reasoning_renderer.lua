-- reasoning_renderer.lua — Renderiza o reasoning do modelo em um box ANSI no replay.
-- Função pura: depende apenas de ui.core (tw, render_dim, wrap_para) e suas cores.
-- v2: colapsa como no live (ui/stream/reasoning_box.lua) — antes mostrava o
-- texto INTEIRO sempre, diferente da experiência ao vivo (que corta com
-- "(+ N linhas)"). Replay agora usa o mesmo padrão visual compacto.
local core = require("ui.core")
local c    = core.c
local M = {}

local MAX_REASONING_LINES = 6

-- Lê o thinking_mode ATUAL da config — não o modo que estava ativo quando
-- a mensagem foi originalmente gerada. Por decisão do Samuel, o replay é
-- dinâmico: reflete sempre o setting vigente agora, pro histórico inteiro.
local function get_thinking_mode()
  local ok, config_mod = pcall(require, "config")
  if ok and config_mod then
    local ok_val, val = pcall(config_mod.get, "agents.defaults.thinking_mode")
    if ok_val and val then
      return val
    end
  end
  return "expanded"
end

-- Variante compacta do replay: mesma filosofia do modo compacto ao vivo
-- (ui/spinner.lua) — não reexibe o texto do raciocínio, só sinaliza que
-- houve pensamento. Sem duração porque o elapsed não é persistido no JSONL.
local function show_reasoning_compact()
  local LBLUE = "\27[38;5;117m"
  local RESET = "\27[0m"
  io.write(LBLUE .. "⬤ " .. "Pensamento" .. RESET .. "\n\n")
  io.flush()
end

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
M.show_reasoning_box     = show_reasoning_box
M.show_reasoning_compact = show_reasoning_compact

-- Ponto de entrada público único: os 4 call-sites em agent/startup.lua devem
-- usar este, não show_reasoning_box direto — é ele que decide o estilo.
function M.show_reasoning(reasoning)
  if not reasoning or reasoning:match("^%s*$") then return end
  if get_thinking_mode() == "compact" then
    show_reasoning_compact()
  else
    show_reasoning_box(reasoning)
  end
end

return M
