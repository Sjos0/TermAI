-- tests/retry_bloco_caminho_real_spec.lua — #327: caminho real do bloco de erro SEM moldura.
-- AO VIVO: chama a função de produção agent/api/request_stream/streamer/fallback.falha_final
--          (o mesmo ponto que a TUI executa ao esgotar as tentativas), capturando o ANSI real.
-- REPLAY: reprocessa esse ANSI byte a byte num emulador de terminal por célula e mede
--         fundo/texto/glifo de cada célula — provando zero moldura e fundo 52.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local function novo_emulador(tw)
  local grid = {}
  local function nova_linha()
    local r = {}
    for i = 1, tw do r[i] = { fundo = nil, texto = nil, glifo = " " } end
    return r
  end
  local row, col, fg, bg = 1, 1, nil, nil
  local function ensure(r) while #grid < r do grid[#grid + 1] = nova_linha() end end
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
        if ok and cp then local g = utf8.char(cp); put(g); i = i + #g
        else put(c); i = i + 1 end
      end
    end
  end
  local function celula(r, c) ensure(r); return grid[r][c] or { fundo = nil, texto = nil, glifo = " " } end
  return { feed = feed, celula = celula }
end

local core = require("ui.core")
local largura = require("ui.largura")
local real_write = io.write
local MOLDURA = {}
for _, ch in ipairs({ "┌","┐","└","┘","─","│","╭","╮","╰","╯",
  "╔","╗","╚","╝","═","║","┏","┓","┗","┛","━","┃" }) do MOLDURA[ch] = true end

local function fresh_retry()
  package.loaded["ui.spinner.retry"] = nil
  local retry = require("ui.spinner.retry")
  -- ui fachada real expõe show_api_error/show_retry = retry.* (ui/spinner.lua:22,24).
  -- Stub só evita carregar a árvore inteira de ui; a chamada final é a REAL.
  package.loaded["ui"] = {
    show_api_error = retry.show_api_error,
    show_retry = retry.show_retry,
    clear_retry_lines = retry.clear_retry_lines,
  }
  return retry
end

local function capturar(fn)
  local writes = {}
  io.write = function(...) writes[#writes + 1] = table.concat({...}); return true end
  local ok, err = pcall(fn)
  io.write = real_write
  assert(ok, "caminho real falhou: " .. tostring(err))
  return table.concat(writes)
end

local fb_factory = require("agent.api.request_stream.streamer.fallback")
local fb = fb_factory({})  -- falha_final não usa M.pensar_stream

local function split_lines(out)
  local lines = {}
  for ln in (out .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = ln end
  if #lines > 0 and lines[#lines] == "" then table.remove(lines) end
  return lines
end

local function medir_e_afirmar(rotulo, out, tw, requer_erro)
  -- REPLAY: reprocessa o ANSI capturado ao vivo no emulador por célula.
  local lines = split_lines(out)
  local em = novo_emulador(tw)
  for _, ln in ipairs(lines) do em.feed(ln .. "\n") end
  for i, ln in ipairs(lines) do
    T(largura.colunas(ln) == tw, string.format("%s tw=%d linha %d largura %d (got %d)",
      rotulo, tw, i, tw, largura.colunas(ln)))
  end
  local mold, sem_bg, total, joined = 0, 0, 0, ""
  for r = 1, #lines do
    for c = 1, tw do
      total = total + 1
      local cell = em.celula(r, c)
      if MOLDURA[cell.glifo] then mold = mold + 1 end
      if cell.fundo ~= 52 then sem_bg = sem_bg + 1 end
      joined = joined .. cell.glifo
    end
  end
  T(mold == 0, string.format("%s tw=%d: zero moldura no caminho real (got %d)", rotulo, tw, mold))
  T(sem_bg == 0, string.format("%s tw=%d: %d células, todas fundo 52 (sem fundo=%d)", rotulo, tw, total, sem_bg))
  if requer_erro ~= false then
    T(joined:find("%[ERRO%]") ~= nil, rotulo .. " tw=" .. tw .. ": [ERRO] presente")
  end
  return joined
end

for _, tw in ipairs({ 40, 80 }) do
  core.tw = function() return tw end

  -- AO VIVO 1: falha final sem sequência órfã (1 linha de conteúdo).
  fresh_retry()
  local ctx1 = { msgs = { { role = "user", content = "oi" } } }
  local out1 = capturar(function()
    fb.falha_final(ctx1, { max_retries = 5 }, "Sem resposta do servidor")
  end)
  local j1 = medir_e_afirmar("vivo", out1, tw)
  T(j1:find("resposta do servidor", 1, true) ~= nil, "vivo tw=" .. tw .. ": motivo presente")

  -- AO VIVO 2: falha final com tool_call órfão (2 linhas: [recover] + [ERRO]).
  fresh_retry()
  local ctx2 = { msgs = {
    { role = "user", content = "oi" },
    { role = "assistant", tool_calls = { { ["function"] = { name = "web_search" } } } },
  } }
  local out2 = capturar(function()
    fb.falha_final(ctx2, { max_retries = 3 }, "HTTP 500 upstream timeout")
  end)
  local j2 = medir_e_afirmar("vivo+recover", out2, tw)
  T(j2:find("web_search", 1, true) ~= nil, "vivo+recover tw=" .. tw .. ": [recover] com web_search")

  -- AO VIVO 3: bloco de TENTATIVA via ui.show_retry (ui/spinner.lua:22).
  local retry = fresh_retry()
  local out3 = capturar(function() retry.show_retry(2, 5, "Sem resposta do servidor", 3) end)
  local j3 = medir_e_afirmar("tentativa", out3, tw, false)
  T(j3:find("Tentativa 2/5", 1, true) ~= nil, "tentativa tw=" .. tw .. ": cabeçalho presente")
end

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)