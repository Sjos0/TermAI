-- ui/tools_init/header.lua — Cabeçalho de uma tool: sempre UMA linha, cortada na largura da tela.
-- Cabeçalho que quebra desalinha a volta do cursor (ESC[nA) e deixa resíduo na TUI.
local core = require("ui.core")
local c    = core.c

local M = {}

-- Corta por caracteres UTF-8 para caber em max colunas; o corte é marcado com "…".
function M.cut_cols(s, max)
  s = tostring(s or "")
  if max <= 0 then return "" end
  local n = utf8.len(s)
  if not n then return s:sub(1, max) end          -- texto inválido em UTF-8: corte bruto
  if n <= max then return s end
  if max == 1 then return "…" end
  return s:sub(1, utf8.offset(s, max) - 1) .. "…"
end

-- Colunas visíveis do cabeçalho ("⬤ " + nome + " (arg)"), limitadas a tw-1 quando tw é dado.
function M.header_vis_len(name, arg, tw)
  local full = 2 + (utf8.len(name or "") or #(name or ""))
  if arg then full = full + 3 + (utf8.len(arg) or #arg) end
  if tw then return math.min(full, tw - 1) end
  return full
end

function M.write_header(dot_color, name, arg)
  local tw     = core.tw()
  local avail  = tw - 3                            -- "⬤ " e uma coluna de folga
  local name_s = M.cut_cols(name, math.max(1, avail))
  local rest   = avail - (utf8.len(name_s) or #name_s)
  local arg_s  = (arg and rest > 3) and M.cut_cols(" (" .. arg .. ")", rest) or ""
  io.write(dot_color .. "⬤ " .. c.reset .. c.bold .. c.white .. name_s .. c.reset)
  if arg_s ~= "" then io.write(c.white .. arg_s .. c.reset) end
  io.write("\n")
end

return M
