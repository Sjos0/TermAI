-- tests/regua_sep2_colunas_334_spec.lua — #334: o SEP2 do menu mede o prefixo em
-- colunas, nao em bytes. Prova, no caminho REAL de producao
-- (commands.config.menus.request.view.print_status/print_options), tres coisas:
--   (a) a regua tem exatamente min(teto=30, tw - 2 - colunas(prefixo)) tracos;
--   (b) nenhuma linha do menu excede tw (40 / 50 / 54);
--   (c) prefixo ASCII continua dando o mesmo resultado (colunas == bytes).
-- tw e injetado por stub de core.tw (mesmo padrao de larguras_responsivas_331_spec.lua).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local core    = require("ui.core")
local largura = require("ui.largura")
local view    = require("commands.config.menus.request.view")

local orig_tw = core.tw
local function set_tw(w) core.tw = function() return w end end

local function capturar(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, err = pcall(fn)
  io.write = orig
  assert(ok, err)
  return table.concat(buf)
end

local function linhas(raw)
  local t = {}
  for ln in (raw .. "\n"):gmatch("([^\n]*)\n") do t[#t + 1] = ln end
  return t
end

local TRACO = "─"

--- Tracos finais da linha visivel: devolve quantidade e o prefixo que veio antes.
--- Anda de tras para frente, 3 bytes por traco (U+2500), para nao confundir
--- byte com coluna.
local function regua_da_linha(vis)
  local i, n = #vis, 0
  while i >= 3 and vis:sub(i - 2, i) == TRACO do n = n + 1; i = i - 3 end
  return n, vis:sub(1, i)
end

--- Todas as linhas com regua do menu real, em tw fixo.
local function linhas_com_regua(tw)
  set_tw(tw)
  local achadas = {}
  local saidas = {
    capturar(function() view.print_status({}, {}) end),
    capturar(function() view.print_options() end),
  }
  for _, out in ipairs(saidas) do
    for _, ln in ipairs(linhas(out)) do
      local vis = largura.visivel(ln)
      local n, pref = regua_da_linha(vis)
      if n > 0 then achadas[#achadas + 1] = { n = n, prefixo = pref, vis = vis } end
    end
  end
  return achadas
end

local TETO = 30

-- ══════════════════════════════════════════════════════════════════════════
print("\n-- (a) regua == min(30, tw - 2 - colunas(prefixo)) no menu real --")
-- ══════════════════════════════════════════════════════════════════════════

for _, tw in ipairs({ 34, 40, 50, 54 }) do
  local achadas = linhas_com_regua(tw)
  T(#achadas >= 2, string.format("[a tw=%d] menu real produziu reguas (n=%d)", tw, #achadas))
  for _, r in ipairs(achadas) do
    local esperado = math.max(0, math.min(TETO, tw - 2 - largura.colunas(r.prefixo)))
    T(r.n == esperado, string.format(
      "[a tw=%d] prefixo=[%s] colunas=%d bytes=%d -> regua=%d esperado=%d",
      tw, r.prefixo, largura.colunas(r.prefixo), #r.prefixo, r.n, esperado))
  end
end

-- ══════════════════════════════════════════════════════════════════════════
print("\n-- (b) medicao por linha: a linha da regua nunca excede tw --")
-- Nota de escopo: as linhas de TEXTO do menu (descricao longa de opcao, ex.
-- a de Thinking Effort) passam de tw — comportamento pre-existente, alheio ao
-- #334 (a issue proibe outras mudancas); quem quebra a linha e o wrap do
-- terminal. O que esta issue controla e prefixo + regua; medimos isso com
-- FAIL e registramos o resto como INFO, com a largura medida.
-- ══════════════════════════════════════════════════════════════════════════

for _, tw in ipairs({ 40, 50, 54 }) do
  local achadas   = linhas_com_regua(tw)
  local pior_rg   = 0
  for _, r in ipairs(achadas) do
    local w = largura.colunas(r.vis)
    if w > pior_rg then pior_rg = w end
    T(w <= tw, string.format("[b tw=%d] linha com regua <= tw (prefixo=%d + regua=%d = %d)",
      tw, largura.colunas(r.prefixo), r.n, w))
  end
  print(string.format("     tw=%d -> pior linha com regua = %d colunas (teto=%d)", tw, pior_rg, tw))

  set_tw(tw)
  local pior_txt, alvo = 0, ""
  for _, out in ipairs({
    capturar(function() view.print_status({}, {}) end),
    capturar(function() view.print_options() end),
  }) do
    for _, ln in ipairs(linhas(out)) do
      local vis = largura.visivel(ln)
      if vis ~= "" and regua_da_linha(vis) == 0 then
        local w = largura.colunas(vis)
        if w > pior_txt then pior_txt, alvo = w, vis end
      end
    end
  end
  print(string.format("     tw=%d -> INFO pior linha sem regua (fora do escopo) = %d colunas: [%s]",
    tw, pior_txt, alvo))
end

-- ══════════════════════════════════════════════════════════════════════════
print("\n-- (c) prefixo ASCII: colunas == bytes, resultado inalterado --")
-- ══════════════════════════════════════════════════════════════════════════

set_tw(40)
for _, p in ipairs({ "  -- Skills Globais ", "  -- Opcoes " }) do
  T(largura.colunas(p) == #p, string.format("[c] prefixo ASCII [%s]: colunas(%d) == bytes(%d)", p, largura.colunas(p), #p))
  T(core.regua(TETO, largura.colunas(p)) == core.regua(TETO, #p),
    string.format("[c] prefixo ASCII [%s]: regua por colunas == regua por bytes", p))
end

core.tw = orig_tw
print(string.format("\n%d falha(s)", failures))
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
