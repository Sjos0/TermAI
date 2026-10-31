-- tests/retry_bloco_sem_borda_spec.lua — #327: bloco de erro/tentativa SEM moldura.
-- Medição POR CÉLULA (fundo, texto, glifo): não remove SGR antes de medir.
-- Emulador espelha tests/emulador_celulas_spec.lua (T1 #282); API {feed, celula}.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- ── Emulador por célula (grid[row][col] = {fundo, texto, glifo}) ──────────────
local function novo_emulador(tw, th)
  tw = tw or 80; th = th or 24
  local grid = {}
  local function nova_linha()
    local r = {}
    for i = 1, tw do r[i] = { fundo = nil, texto = nil, glifo = " " } end
    return r
  end
  for r = 1, th do grid[r] = nova_linha() end
  local row, col, fg, bg = 1, 1, nil, nil
  local function ensure(r)
    while #grid < r do grid[#grid + 1] = nova_linha() end
  end
  local function put(ch)
    if col > tw then row = row + 1; col = 1 end
    ensure(row)
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
        local seq = raw:sub(i):match("^(\27%[([0-9;]*)([A-Za-z]))")
        if seq then
          local params = seq:match("^\27%[([0-9;]*)") or ""
          local letter = seq:sub(-1)
          if letter == "m" then parse_sgr(params)
          elseif letter == "A" then row = math.max(1, row - (tonumber(params) or 1)); col = 1
          elseif letter == "J" then
            local mode = tonumber(params) or 0
            if mode == 0 or mode == 2 then for r = row, #grid do grid[r] = nova_linha() end end
            if mode == 2 then for r = 1, row - 1 do grid[r] = nova_linha() end end
          elseif letter == "K" then
            local mode = tonumber(params) or 0
            ensure(row)
            if mode == 2 then grid[row] = nova_linha(); col = 1
            elseif mode == 0 then for cc = col, tw do grid[row][cc] = { fundo = nil, texto = nil, glifo = " " } end end
          end
          i = i + #seq
        else i = i + 1 end
      elseif c == "\r" then col = 1; i = i + 1
      elseif c == "\n" then row = row + 1; col = 1; i = i + 1
      else
        local ok, cp = pcall(utf8.codepoint, raw, i)
        if ok and cp then
          local g = utf8.char(cp); put(g); i = i + #g
        else put(c); i = i + 1 end
      end
    end
  end
  local function celula(r, c)
    ensure(r)
    return grid[r][c] or { fundo = nil, texto = nil, glifo = " " }
  end
  return { feed = feed, celula = celula }
end

local core = require("ui.core")
local largura = require("ui.largura")
local real_write = io.write

local function capturar(fn)
  local writes = {}
  io.write = function(...) writes[#writes + 1] = table.concat({...}); return true end
  local ok, err = pcall(fn)
  io.write = real_write
  assert(ok, "falha ao executar caminho real: " .. tostring(err))
  return table.concat(writes)
end

local function fresh_retry()
  package.loaded["ui.spinner.retry"] = nil
  return require("ui.spinner.retry")
end

local function split_lines(out)
  local lines = {}
  for ln in (out .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = ln end
  if #lines > 0 and lines[#lines] == "" then table.remove(lines) end
  return lines
end

-- Glifos de moldura de TODOS os tipos (PLAIN/ROUNDED/DOUBLE/THICK).
local MOLDURA = {}
for _, ch in ipairs({ "┌","┐","└","┘","─","│","╭","╮","╰","╯",
  "╔","╗","╚","╝","═","║","┏","┓","┗","┛","━","┃" }) do MOLDURA[ch] = true end

local LONG = "Falha após 5 tentativas — HTTP 500: upstream timeout detail o gateway nao"
  .. " respondeu dentro do limite de 30s e o detalhe continua aqui para forcar a"
  .. " quebra por palavra sem perder nenhum caractere do texto original"

for _, tw in ipairs({ 40, 50, 80 }) do
  core.tw = function() return tw end

  -- (A) bloco de ERRO final (show_api_error) ─────────────────────────────────
  local retry = fresh_retry()
  local out = capturar(function()
    retry.show_api_error(LONG, "[recover] sequencia removida: web_search")
  end)
  local lines = split_lines(out)
  local em = novo_emulador(tw, #lines + 2)
  for _, ln in ipairs(lines) do em.feed(ln .. "\n") end

  for i, ln in ipairs(lines) do
    T(largura.colunas(ln) == tw,
      string.format("erro tw=%d linha %d largura exata %d (got %d)", tw, i, tw, largura.colunas(ln)))
  end

  local mold, sem_bg, total = 0, 0, 0
  local joined = ""
  for r = 1, #lines do
    for c = 1, tw do
      total = total + 1
      local cell = em.celula(r, c)
      if MOLDURA[cell.glifo] then mold = mold + 1 end
      if cell.fundo ~= 52 then sem_bg = sem_bg + 1 end
      joined = joined .. cell.glifo
    end
  end
  T(mold == 0, string.format("erro tw=%d: zero glifo de moldura (got %d)", tw, mold))
  T(sem_bg == 0, string.format("erro tw=%d: todas as %d células com fundo 52 (sem fundo=%d)", tw, total, sem_bg))
  T(#lines >= 4, "erro tw=" .. tw .. ": texto longo ocupou >=4 linhas, com respiro (got " .. #lines .. ")")
  T(joined:find("upstream", 1, true) ~= nil, "erro tw=" .. tw .. ": inicio do texto sem perda ('upstream')")
  T(joined:find("caractere", 1, true) ~= nil, "erro tw=" .. tw .. ": ultima palavra sem perda ('caractere')")
  T(joined:find("%[ERRO%]") ~= nil, "erro tw=" .. tw .. ": marca [ERRO] presente")

  -- (B) bloco de TENTATIVA (show_retry) ──────────────────────────────────────
  retry = fresh_retry()
  local out2 = capturar(function() retry.show_retry(2, 5, "Sem resposta do servidor", 3) end)
  local l2 = split_lines(out2)
  local em2 = novo_emulador(tw, #l2 + 2)
  for _, ln in ipairs(l2) do em2.feed(ln .. "\n") end

  for i, ln in ipairs(l2) do
    T(largura.colunas(ln) == tw,
      string.format("tentativa tw=%d linha %d largura exata %d (got %d)", tw, i, tw, largura.colunas(ln)))
  end
  local mold2, bg2 = 0, 0
  for r = 1, #l2 do
    for c = 1, tw do
      local cell = em2.celula(r, c)
      if MOLDURA[cell.glifo] then mold2 = mold2 + 1 end
      if cell.fundo ~= 52 then bg2 = bg2 + 1 end
    end
  end
  T(mold2 == 0, "tentativa tw=" .. tw .. ": zero glifo de moldura (got " .. mold2 .. ")")
  T(bg2 == 0, "tentativa tw=" .. tw .. ": todas as células com fundo 52 (sem fundo=" .. bg2 .. ")")
end

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
