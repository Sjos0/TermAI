-- tests/emulador_celulas_spec.lua — #282 T1: emulador por célula (CSI/SGR).
-- Não importa ui/largura, ui/card, ui/widgets/*; não remove SGR antes de medir.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- ── Emulador por célula ─────────────────────────────────────────────────────
local function novo_emulador(tw, th)
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
        local seq, cmd = rest:match("^(\27%[([0-9;]*)([A-Za-z]))")
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
        put(c)
        i = i + 1
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

-- Export for other specs via package
package.loaded["tests.emulador_celulas"] = {
  novo = novo_emulador,
}

-- ── Verificação mínima obrigatória (#282 T1) ────────────────────────────────
do
  local em = novo_emulador(10, 5)
  em.feed("\27[48;5;52mABC\27[0m")
  local c1 = em.celula(1, 1)
  local c2 = em.celula(1, 2)
  local c3 = em.celula(1, 3)
  local c4 = em.celula(1, 4)
  T(c1.fundo == 52 and c1.glifo == "A", "col1 fundo 52 glifo A (got fundo=" .. tostring(c1.fundo) .. " g=" .. c1.glifo .. ")")
  T(c2.fundo == 52 and c2.glifo == "B", "col2 fundo 52 glifo B")
  T(c3.fundo == 52 and c3.glifo == "C", "col3 fundo 52 glifo C")
  T(c4.fundo == nil, "col4 sem fundo apos reset (got " .. tostring(c4.fundo) .. ")")
end

-- SGR texto 38;5;n
do
  local em = novo_emulador(8, 3)
  em.feed("\27[38;5;231mX\27[0m")
  local c = em.celula(1, 1)
  T(c.texto == 231 and c.glifo == "X", "fg 231 no glifo X")
  T(em.celula(1, 2).texto == nil, "fg limpo apos reset")
end

-- ESC[nA + reescrita
do
  local em = novo_emulador(10, 5)
  em.feed("AAAA\nBBBB")
  em.feed("\27[1A\27[2KCCCC")
  T(em.celula(1, 1).glifo == "C", "ESC[1A+2K reescreve linha 1")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
