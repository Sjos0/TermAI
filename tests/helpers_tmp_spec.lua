-- tests/helpers_tmp_spec.lua — Testa o helper tests/helpers/tmp.lua (issue #128).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local tmp = require("tests.helpers.tmp")

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local function sec(title) print("\n=== " .. title .. " ===") end

-- Base gravável de referência, resolvida pelo próprio helper (ambiente real).
local base = tmp.dir()

sec("1. /tmp somente leitura -> fallback")
-- /proc nunca aceita escrita, nem como root: simula o /tmp read-only do Android.
local ro = "/proc"
local dir_ro = tmp.resolve({ ro, base })
T("/proc (read-only) é recusado e cai no próximo candidato", dir_ro ~= nil and dir_ro:sub(1, #base) == base)
T("o diretório escolhido não está dentro do candidato read-only", dir_ro ~= nil and dir_ro:sub(1, #ro) ~= ro)

sec("2. Ordem de preferência")
T("primeiro candidato gravável vence", tmp.resolve({ base, ro }):sub(1, #base) == base)

sec("3. $TMPDIR vazio ou inexistente")
local env_vazio = function(k) if k == "TMPDIR" then return "" end if k == "HOME" then return "/h" end end
local cands_vazio = tmp.default_candidates(env_vazio)
local tem_vazio = false
for _, c in ipairs(cands_vazio) do if c == "" or c == nil then tem_vazio = true end end
T("TMPDIR vazio não entra na lista de candidatos", not tem_vazio)
local env_inexist = function(k) if k == "TMPDIR" then return "/nao/existe/termai_xyz" end if k == "HOME" then return "/h" end end
local dir_inex = tmp.resolve({ "/nao/existe/termai_xyz", base })
T("TMPDIR inexistente é ignorado sem criar o caminho", dir_inex ~= nil and dir_inex:sub(1, #base) == base
  and io.open("/nao/existe/termai_xyz", "r") == nil)
T("default_candidates usa HOME/.TermAI/workspace/tmp como candidato", (function()
  for _, c in ipairs(tmp.default_candidates(env_inexist)) do
    if c == "/h/.TermAI/workspace/tmp" then return true end
  end
  return false
end)())

sec("4. Nenhum candidato gravável")
T("resolve devolve nil quando nada é gravável", tmp.resolve({ "/proc", "/nao/existe/termai_xyz" }) == nil)

sec("5. Cache, nomes e limpeza")
local d1, d2 = tmp.dir(), tmp.dir()
T("dir() é cacheado (mesmo caminho)", d1 == d2)
T("dir() existe e é gravável", io.open(d1 .. "/.x", "w") ~= nil and os.remove(d1 .. "/.x") ~= nil)
local n = tmp.name("alvo")
T("name() fica dentro do diretório temporário", n:sub(1, #d1 + 1) == d1 .. "/")
T("name() inclui o sufixo pedido", n:find("/alvo_", 1, true) ~= nil)
T("name() não cria o caminho", io.open(n, "r") == nil)
T("sentinela de limpeza existe", tmp._sentinel ~= nil)
tmp.cleanup()
local ainda_existe = os.execute("test -d '" .. d1 .. "'")
T("cleanup() remove o diretório", not ainda_existe)

print(string.format("\nRESULTADO (helpers tmp): %d passaram, %d falharam", pass, fail))
if fail > 0 then os.exit(1) end
