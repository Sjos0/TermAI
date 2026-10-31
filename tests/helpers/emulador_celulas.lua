-- tests/helpers/emulador_celulas.lua — emulador de terminal por célula (CSI/SGR).
-- Extraído de tests/emulador_celulas_spec.lua (#331) para ser reutilizado por
-- outros specs (ex.: larguras_responsivas_331_spec.lua) sem duplicar a grade.
-- Não importa ui/largura, ui/card nem ui/widgets/*: é um medidor independente.
local M = {}

--- Cria um emulador de grade tw×th.
-- @param tw number largura em colunas (default 80)
-- @param th number altura em linhas (default 24)
-- @return table { feed = função, celula = função, grid = grade }
function M.novo(tw, th)
  tw = tw or 80
  th = th or 24
  local grid = {} -- grid[row][col] = {fundo=n|nil, texto=n|nil, glifo=ch}
  for r = 1, th do
    grid[r] = {}
    for c = 1, tw do grid[r][c] = { fundo = nil, texto = nil, glifo = " " } end
  end
  local row, col = 1, 1
  local fg, bg = nil, nil

  local function ensure(r, c)
    while #grid < r do
      local nr = {}
      for i = 1, tw do nr[i] = { fundo = nil, texto = nil, glifo = " " } end
      grid[#grid + 1] = nr
    end
    if not grid[r][c] then
      for i = 1, tw do
        if not grid[r][i] then grid[r][i] = { fundo = nil, texto = nil, glifo = " " } end
      end
    end
  end

  local function put(ch)
    if col > tw then
      row = row + 1
      col = 1
    end
    ensure(row, col)
    grid[row][col] = { fundo = bg, texto = fg, glifo = ch }
    col = col + 1
  end

  local function parse_sgr(params)
    if params == "" or params == "0" then
      fg, bg = nil, nil
      return
    end
    local parts = {}
    for p in (params .. ";"):gmatch("([^;]*);") do parts[#parts + 1] = tonumber(p) or 0 end
    local i = 1
    while i <= #parts do
      local n = parts[i]
      if n == 0 then
        fg, bg = nil, nil
      elseif n == 38 and parts[i + 1] == 5 and parts[i + 2] then
        fg = parts[i + 2]; i = i + 2
      elseif n == 48 and parts[i + 1] == 5 and parts[i + 2] then
        bg = parts[i + 2]; i = i + 2
      elseif n == 39 then
        fg = nil
      elseif n == 49 then
        bg = nil
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
          local n = tonumber(params) or (letter == "A" and 1 or 0)
          if letter == "A" then
            row = math.max(1, row - n)
            col = 1
          elseif letter == "J" then
            local mode = tonumber(params) or 0
            if mode == 0 or mode == 2 then
              for r = row, #grid do
                for cc = 1, tw do grid[r][cc] = { fundo = nil, texto = nil, glifo = " " } end
              end
            end
            if mode == 2 then
              for r = 1, row - 1 do
                for cc = 1, tw do grid[r][cc] = { fundo = nil, texto = nil, glifo = " " } end
              end
            end
          elseif letter == "K" then
            local mode = tonumber(params) or 0
            ensure(row, 1)
            if mode == 2 then
              for cc = 1, tw do grid[row][cc] = { fundo = nil, texto = nil, glifo = " " } end
              col = 1
            elseif mode == 0 then
              for cc = col, tw do grid[row][cc] = { fundo = nil, texto = nil, glifo = " " } end
            end
          elseif letter == "m" then
            parse_sgr(params)
          end
          i = i + #seq
        else
          i = i + 1
        end
      elseif c == "\r" then
        col = 1
        i = i + 1
      elseif c == "\n" then
        row = row + 1
        col = 1
        i = i + 1
      else
        -- Decodifica UTF-8: agrupa os bytes de um code point numa única
        -- célula (o emulador original era byte-a-byte e só enxergava ASCII,
        -- então o glifo "─" nunca casava nas buscas por célula).
        -- Larguras 1 e 2 ocupam 1 célula aqui — suficiente para separadores.
        local b = raw:byte(i)
        local len = (b < 0x80) and 1 or (b < 0xE0) and 2 or (b < 0xF0) and 3 or 4
        put(raw:sub(i, i + len - 1))
        i = i + len
      end
    end
  end

  local function celula(linha, coluna)
    ensure(linha, coluna)
    local cell = grid[linha] and grid[linha][coluna]
    if not cell then return { fundo = nil, texto = nil, glifo = " " } end
    return { fundo = cell.fundo, texto = cell.texto, glifo = cell.glifo }
  end

  return { feed = feed, celula = celula, grid = grid }
end

return M
