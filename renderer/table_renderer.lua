-- table_renderer.lua — Detecção, parsing e renderização de tabelas markdown.
-- Tabelas (linhas começando com "|") são convertidas em bullets "chave: valor",
-- mais legível em terminal estreito do que colunas alinhadas. flush_table é um
-- mini state-machine: detecta linha de header, separador (|---|---|) e linhas
-- de dados, então formata.
local md = require("renderer.markdown")
local M = {}

local ESC = "\27["

local function is_table_row(s)   return s:match("^%s*|") ~= nil end

local function is_separator_row(s)
  local inner = s:match("^%s*|(.+)|%s*$")
  if not inner then return false end
  return inner:match("^[%s|%-%:]+$") ~= nil
end

local function parse_cells(s)
  local cells = {}
  local inner = s:match("^%s*|(.+)|%s*$") or s:match("^%s*|(.+)$") or ""
  for cell in (inner .. "|"):gmatch("([^|]*)|") do
    cells[#cells + 1] = cell:match("^%s*(.-)%s*$")
  end
  return cells
end

local function flush_table(tbl_lines, out)
  if #tbl_lines == 0 then return end
  local headers, rows = nil, {}
  for _, line in ipairs(tbl_lines) do
    if is_separator_row(line) then
    elseif headers == nil then headers = parse_cells(line)
    else rows[#rows + 1] = parse_cells(line) end
  end
  if not headers then return end
  if #rows == 0 then
    local parts = {}
    for _, h in ipairs(headers) do
      if h ~= "" then parts[#parts + 1] = ESC.."1m"..md.render_inline(h)..ESC.."22m" end
    end
    if #parts > 0 then
      out[#out + 1] = "  "..ESC.."38;5;245m•"..ESC.."0m "
                   .. table.concat(parts, ESC.."38;5;245m · "..ESC.."0m")
    end
    return
  end
  for _, row in ipairs(rows) do
    local parts = {}
    for i, cell in ipairs(row) do
      if cell ~= "" then
        local label = (headers[i] and headers[i] ~= "")
                      and (ESC.."1m"..md.render_inline(headers[i])..":"..ESC.."22m ")
                      or  ""
        parts[#parts + 1] = label .. md.render_inline(cell)
      end
    end
    if #parts > 0 then
      out[#out + 1] = "  "..ESC.."38;5;245m•"..ESC.."0m "
                   .. table.concat(parts, ESC.."38;5;245m  ·  "..ESC.."0m")
    end
  end
end

M.is_table_row = is_table_row
M.flush_table  = flush_table
return M
