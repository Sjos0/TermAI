-- Formatação de linhas de saúde para as interfaces CLI e TUI.
local wrap = require("ui.largura_wrap")
local largura = require("ui.largura")
local M = {}

local INDENTACAO_METADATA <const> = "     "
local LARGURA_TERMINAL_PADRAO <const> = 80

-- Formata metadados de saúde com continuações alinhadas à segunda linha da chave.
function M.format_last(last, width)
  local terminal_width = tonumber(width) or LARGURA_TERMINAL_PADRAO
  local available = math.max(1, terminal_width - largura.colunas(INDENTACAO_METADATA))
  local wrapped = wrap.quebrar(last, available, largura.colunas)
  local lines = {}
  for _, line in ipairs(wrapped) do
    lines[#lines + 1] = INDENTACAO_METADATA .. line
  end
  return lines
end

return M
