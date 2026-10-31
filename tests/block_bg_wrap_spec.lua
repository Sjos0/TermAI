-- tests/block_bg_wrap_spec.lua — #269 + #282 T2: Block bg/wrap + verificação por célula.
-- Medição por célula: não remove SGR antes de medir (usa tests.emulador_celulas).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- carrega emulador (lado do teste; não é produção)
-- dofile rodaria os testes e sairia — em vez disso, reimplementação mínima inline
-- da API de célula só para este arquivo (espelho do emulador T1, sem depender do exit).

local function novo_emulador(tw, th)
  tw = tw or 80; th = th or 24
  local grid = {}
  for r = 1, th do
    grid[r] = {}
    for c = 1, tw do grid[r][c] = { fundo = nil, texto = nil, glifo = " " } end
  end
  local row, col, fg, bg = 1, 1, nil, nil
  local function ensure(r, c)
    while #grid < r do
      local nr = {}
      for i = 1, tw do nr[i] = { fundo = nil, texto = nil, glifo = " " } end
      grid[#grid + 1] = nr
    end
  end
  local function put(ch)
    if col > tw then row = row + 1; col = 1 end
    ensure(row, col)
    grid[row][col] = { fundo = bg, texto = fg, glifo = ch }
    col = col + 1
  end
  local function parse_sgr(params)
    if params == "" or params == "0" then fg, bg = nil, nil; return end
    local parts = {}
    for p in (params .. ";"):gmatch("([^;]*);") do parts[#parts + 1] = tonumber(p) or 0 end
    local i = 1
    while i <= #parts do
      local n = parts[i]
      if n == 0 then fg, bg = nil, nil
      elseif n == 38 and parts[i + 1] == 5 and parts[i + 2] then fg = parts[i + 2]; i = i + 2
      elseif n == 48 and parts[i + 1] == 5 and parts[i + 2] then bg = parts[i + 2]; i = i + 2
      elseif n == 39 then fg = nil
      elseif n == 49 then bg = nil
      end
      i = i + 1
    end
  end
  local function feed(raw)
    raw = tostring(raw or "")
    local i = 1
    while i <= #raw do
      local c = raw:sub(i, i)
      if c == "\27" then
        local rest = raw:sub(i)
        local seq = rest:match("^(\27%[([0-9;]*)([A-Za-z]))")
        if seq then
          local params = seq:match("^\27%[([0-9;]*)") or ""
          local letter = seq:sub(-1)
          if letter == "m" then parse_sgr(params)
          elseif letter == "A" then
            row = math.max(1, row - (tonumber(params) or 1)); col = 1
          elseif letter == "K" then
            local mode = tonumber(params) or 0
            ensure(row, 1)
            if mode == 2 then for cc = 1, tw do grid[row][cc] = { fundo = nil, texto = nil, glifo = " " } end; col = 1
            elseif mode == 0 then for cc = col, tw do grid[row][cc] = { fundo = nil, texto = nil, glifo = " " } end end
          end
          i = i + #seq
        else i = i + 1 end
      elseif c == "\r" then col = 1; i = i + 1
      elseif c == "\n" then row = row + 1; col = 1; i = i + 1
      else put(c); i = i + 1 end
    end
  end
  local function celula(linha, coluna)
    ensure(linha, coluna)
    return grid[linha][coluna] or { fundo = nil, texto = nil, glifo = " " }
  end
  return { feed = feed, celula = celula }
end

local block = require("ui.widgets.block")
local largura = require("ui.largura")
local function plain(s) return (s or ""):gsub("\27%[[0-9;:?]*[A-Za-z]", "") end
local function vis(s) return largura.colunas(plain(s)) end

-- Critério 1 legado: SGR de fundo presente + largura
do
  local BG = "\27[48;5;52m"
  local FG = "\27[38;5;255m"
  local b = block.new({
    borders = block.BORDERS.ALL,
    border_type = block.TYPE.PLAIN,
    border_color = "\27[38;5;203m",
    bg = BG, fg = FG,
    content_lines = { "erro curto" },
  })
  local lines = b:render({ w = 40, h = 3 })
  T(#lines == 3, "bg h=3 -> 3 linhas (got " .. #lines .. ")")
  local all_have_bg = true
  for i, ln in ipairs(lines) do
    if not ln:find("48;5;52", 1, true) then all_have_bg = false end
    T(vis(ln) == 40, "linha " .. i .. " largura visual 40 (got " .. vis(ln) .. ")")
  end
  T(all_have_bg, "todas as linhas carregam SGR de fundo bg_error")

  -- #282 T2: verificação por célula — fundo 52 em todas as células do bloco
  local em = novo_emulador(40, 6)
  for _, ln in ipairs(lines) do em.feed(ln .. "\n") end
  local missing = 0
  for r = 1, 3 do
    for c = 1, 40 do
      local cell = em.celula(r, c)
      if cell.fundo ~= 52 then missing = missing + 1 end
    end
  end
  T(missing == 0, "por célula: todas as células do bloco tem fundo 52 (missing=" .. missing .. ")")
end

-- Critério 2: texto longo quebra por palavra (h=nil)
do
  local long = "Falha após 5 tentativas — HTTP 500: upstream timeout gateway nao respondeu dentro do limite de 30s e o detalhe continua aqui para forcar wrap"
  local b = block.new({
    borders = block.BORDERS.ALL,
    bg = "\27[48;5;52m", fg = "\27[38;5;255m",
    content_lines = { long },
  })
  local lines = b:render({ w = 40, h = nil })
  T(#lines >= 4, "h=nil com texto longo -> altura >= 4 (got " .. #lines .. ")")
  local body_count = 0
  for i = 2, #lines - 1 do
    body_count = body_count + 1
    T(vis(lines[i]) == 40, "corpo linha " .. i .. " largura 40")
  end
  T(body_count >= 2, "texto longo gerou >=2 linhas de corpo (got " .. body_count .. ")")
  local joined = ""
  for i = 2, #lines - 1 do joined = joined .. plain(lines[i]) end
  T(joined:find("timeout", 1, true) ~= nil, "palavra 'timeout' intacta apos wrap")
end

-- Critério 3: palavra sem espaço maior que inner.w
do
  local huge = string.rep("A", 80)
  local b = block.new({ borders = block.BORDERS.ALL, content_lines = { huge } })
  local lines = b:render({ w = 20, h = nil })
  T(#lines >= 5, "palavra longa quebra em varias linhas (got " .. #lines .. ")")
  for i, ln in ipairs(lines) do
    T(vis(ln) == 20, "palavra longa linha " .. i .. " w=20")
  end
end

-- Critério 4: regressão sem bg
do
  local b = block.new({ borders = block.BORDERS.ALL, border_type = block.TYPE.PLAIN })
  local lines = b:render({ w = 30, h = 3 })
  T(#lines == 3 and vis(lines[1]) == 30, "regressao sem bg: 3x30")
  local p = plain(lines[1])
  T(p:find("┌", 1, true) and p:find("┐", 1, true), "regressao cantos PLAIN")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
