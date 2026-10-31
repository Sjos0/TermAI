-- tests/status_sem_simbolo_spec.lua
-- #352 (D6 do #325) — trava o contrato do fim do formato antigo: símbolos de status
-- não voltam para as mensagens dos diretórios de produção.
--
-- Critério A da regra de contagem (corpo da #325, fonte de verdade):
--   - conta o símbolo BASE da lista; o seletor de variação U+FE0F (VS16) que o segue
--     conta como PARTE dele, e não como ocorrência própria (por isso aqui se conta só
--     o glifo base);
--   - os glifos ESTRUTURAIS (caixas, marcador do card, prompt) NÃO contam e devem
--     continuar lá.
-- Escopo da varredura: os sete diretórios de produção — o D6 inclui lib/.
--
-- Este spec é a forma mecânica da verificação final da issue: reintroduzir um símbolo
-- de status em qualquer arquivo de produção o derruba (prova de sensibilidade).
-- Observação: a lista oficial de símbolos termina com um "i" solto, que é ambíguo
-- (letra comum não é distinguível de texto). Aqui o item é lido como ⓘ (U+24D8).
--
-- Caminho real: lê os arquivos como estão no disco (mesma convenção de
-- tests/independencia_spec.lua), não funções isoladas.

local pass, fail = 0, 0
local function TEST(name, ok, detail)
  if ok then
    pass = pass + 1
    print("ok   - " .. name)
  else
    fail = fail + 1
    print("FAIL - " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local DIRS = { "ui", "agent", "tools", "commands", "providers", "channels", "lib" }

local STATUS = {
  ["✅"] = "OK",     ["❌"] = "FAIL",   ["⚠"] = "WARN",   ["✓"] = "OK",
  ["✗"] = "FAIL",    ["⚡"] = "FAST",   ["⚙"] = "CONFIG", ["★"] = "STAR",
  ["🔍"] = "SEARCH", ["🔎"] = "SEARCH", ["💡"] = "TIP",   ["🚫"] = "BLOCKED",
  ["🔄"] = "RESTART", ["🔒"] = "LOCKED", ["📭"] = "EMPTY", ["📊"] = "STATS",
  ["📋"] = "LIST",   ["📁"] = "DIR",    ["📄"] = "FILE",  ["📅"] = "DATE",
  ["🧠"] = "MEMORY", ["📖"] = "DOCS",   ["📎"] = "LINK",  ["⏭"] = "SKIP",
  ["⏳"] = "WAIT",   ["⏱"] = "TIMER",  ["↻"] = "RESTART", ["⟳"] = "RESTART",
  ["↷"] = "ARROW",   ["ⓘ"] = "INFO",
}

local ESTRUTURAIS = {
  "⬤", "❯", "─", "│", "┌", "┐", "└", "┘", "╭", "╮", "╰", "╯", "═", "║", "▸", "•",
}

local function arquivos()
  local out = {}
  for _, d in ipairs(DIRS) do
    local h = io.popen('find "' .. d .. '" -type f 2>/dev/null')
    if h then
      for linha in h:lines() do out[#out + 1] = linha end
      h:close()
    end
  end
  return out
end

local function ler(rel)
  local f = io.open(rel, "rb")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

-- Conta ocorrências do glifo dentro da linha, por bytes (os glifos não têm caractere
-- mágico de padrão Lua, então o próprio glifo serve de padrão literal).
local function contar(linha, glifo)
  local _, n = linha:gsub(glifo, "")
  return n
end

print("=== #352: critério A (símbolo base) nos diretórios de produção ===\n")

local fontes = arquivos()
TEST("a varredura encontra arquivos de produção (rode da raiz do repositório)",
  #fontes > 0, "find não devolveu nenhum arquivo")

local por_dir, total_status, total_estrut = {}, 0, 0
for _, d in ipairs(DIRS) do por_dir[d] = { status = 0, estrut = 0 } end

for _, rel in ipairs(fontes) do
  local dir = rel:match("^([^/]+)/")
  local src = ler(rel)
  if src and dir and por_dir[dir] then
    local n = 0
    for linha in (src .. "\n"):gmatch("(.-)\n") do
      for glifo in pairs(STATUS) do
        local c = contar(linha, glifo)
        if c > 0 then
          n = n + c
          print(string.format("  símbolo de status: %s — %s", rel, linha:gsub("%s+$", "")))
        end
      end
      for _, glifo in ipairs(ESTRUTURAIS) do
        local c = contar(linha, glifo)
        por_dir[dir].estrut = por_dir[dir].estrut + c
        total_estrut = total_estrut + c
      end
    end
    por_dir[dir].status = por_dir[dir].status + n
    total_status = total_status + n
  end
end

for _, d in ipairs(DIRS) do
  print(string.format("  %-11s símbolos=%d estruturais=%d", d .. "/",
    por_dir[d].status, por_dir[d].estrut))
end

TEST("zero símbolos de status nos sete diretórios de produção (critério A)",
  total_status == 0, total_status .. " ocorrência(s)")

TEST("estruturais preservados (caixas, marcador do card e prompt continuam presentes)",
  total_estrut > 0, total_estrut .. " ocorrência(s)")

TEST("o helper (lib/result.lua) existe e está dentro do escopo varrido",
  ler("lib/result.lua") ~= nil)

print(string.format("\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══", pass, fail, pass + fail))

if fail > 0 then
  os.exit(1)
end
