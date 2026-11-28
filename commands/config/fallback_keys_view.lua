-- Formatação de linhas de saúde para as interfaces CLI e TUI.
local wrap = require("ui.largura_wrap")
local largura = require("ui.largura")
local M = {}

local INDENTACAO_IDENTIDADE <const> = "  "
local INDENTACAO_CONTINUACAO <const> = "     "

local function quebrar_indentado(texto, width, primeira_indentacao)
  local limite = math.max(1, width - largura.colunas(INDENTACAO_CONTINUACAO))
  local wrapped = wrap.quebrar(texto, limite, largura.colunas)
  local lines = { primeira_indentacao .. wrapped[1] }
  for i = 2, #wrapped do
    lines[#lines + 1] = INDENTACAO_CONTINUACAO .. wrapped[i]
  end
  return lines
end

-- Formata a identidade e o estado da chave sem ultrapassar a largura informada.
function M.format_identity(row, width)
  local terminal_width = assert(tonumber(width), "format_identity requer largura do terminal")
  local active = row.active and " [ATIVA]" or ""
  local identity = string.format("%d. %s  %s%s", row.index, row.masked, row.state, active)
  return quebrar_indentado(identity, terminal_width, INDENTACAO_IDENTIDADE)
end

-- Formata metadados de saúde com continuações alinhadas à segunda linha da chave.
function M.format_last(last, width)
  local terminal_width = assert(tonumber(width), "format_last requer largura do terminal")
  return quebrar_indentado(tostring(last or ""), terminal_width, INDENTACAO_CONTINUACAO)
end

return M
