-- ui/card.lua — Componente Card reutilizável: cada tool é um card. Regras de exibição:
--   1. cabeçalho sempre numa linha, cortado por COLUNAS (UTF-8), nunca quebra a tela;
--   2. corpo recolhido em no máximo MAX_BODY linhas, cada uma cortada na largura;
--   3. nada que seja texto de tool sai com bytes cortados no meio de um caractere.
-- Função pura: não escreve na tela. Quem escreve é o executor (ui/tools_init/*).
local M = {}

M.MAX_BODY = 5

-- Corta s para caber em max colunas (caracteres UTF-8). Marca o corte com "…".
function M.cut(s, max)
  s = tostring(s or "")
  if max <= 0 then return "" end
  local n = utf8.len(s)
  if not n then return s:sub(1, max) end           -- UTF-8 inválido: corte bruto, sem erro
  if n <= max then return s end
  if max == 1 then return "…" end
  return s:sub(1, utf8.offset(s, max) - 1) .. "…"
end

-- Largura visível de um texto (caracteres, não bytes).
function M.width(s)
  return utf8.len(tostring(s or "")) or #tostring(s or "")
end

-- Cabeçalho plano "nome (arg)" cabendo em tw-3 colunas ("⬤ " + folga de 1).
function M.header_parts(name, arg, tw)
  local avail = math.max(1, tw - 3)
  local name_s = M.cut(name, avail)
  local rest = avail - M.width(name_s)
  local arg_s = (arg and rest > 3) and M.cut(" (" .. arg .. ")", rest) or ""
  return name_s, arg_s
end

-- Linhas do corpo, já prontas em texto puro: prefixo " │ " ou " └─ " na última visível,
-- e " └─ ... (N linhas)" quando houver mais que MAX_BODY. Cada linha cabe em tw colunas.
function M.body_rows(lines, tw)
  local rows = {}
  local visible = math.min(#lines, M.MAX_BODY)
  local body_w = math.max(1, tw - 8)
  for i = 1, visible do
    local prefix = (i == visible and #lines <= M.MAX_BODY) and " └─ " or " │ "
    rows[#rows + 1] = { prefix = prefix, text = M.cut(lines[i], body_w) }
  end
  if #lines > M.MAX_BODY then
    rows[#rows + 1] = { prefix = " └─ ", text = "... (" .. (#lines - M.MAX_BODY) .. " linhas)", dim = true }
  end
  return rows
end

return M
