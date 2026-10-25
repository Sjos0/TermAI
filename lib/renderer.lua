-- renderer.lua — Fachada + Pipeline de renderização markdown → ANSI.
-- Aplica símbolos LaTeX, depois percorre o texto linha por linha despachando
-- para code fences, tabelas ou markdown conforme o tipo de cada linha.
-- Interface pública: M.render(s)
local latex = require("renderer.latex")
local md    = require("renderer.markdown")
local tbl   = require("renderer.table_renderer")
local code  = require("renderer.code_renderer")
local M = {}

function M.render(s)
  s = s or ""
  s = latex.apply_latex(s)

  local out      = {}
  local in_code  = false
  local in_table = false
  local tbl_buf  = {}
  local lang     = ""
  local width    = code.tw()

  local function close_table()
    if in_table then
      tbl.flush_table(tbl_buf, out)
      tbl_buf  = {}
      in_table = false
    end
  end

  for line in (s.."\n"):gmatch("([^\n]*)\n") do
    local fence_lang = line:match("^```(.*)")
    if fence_lang ~= nil then
      close_table()
      if not in_code then
        in_code = true
        lang    = fence_lang:match("^%s*(%S*)") or ""
        out[#out + 1] = code.code_fence(lang)
      else
        in_code = false
        out[#out + 1] = code.code_fence("")
        lang = ""
      end
    elseif in_code then
      out[#out + 1] = code.code_line(line, width)
    elseif tbl.is_table_row(line) then
      in_table = true
      tbl_buf[#tbl_buf + 1] = line
    else
      close_table()
      out[#out + 1] = md.render_line(line)
    end
  end

  close_table()
  if in_code then out[#out + 1] = code.code_fence("") end

  local result = table.concat(out, "\n")
  if result:sub(-1) == "\n" then result = result:sub(1, -2) end
  return result
end

return M
