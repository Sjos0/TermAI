-- tests/lib_result_spec.lua
-- #343 — Helper único de resultado: aceitar os dois formatos (símbolo e palavra)
-- num ponto único. (Passo 2 da opção D — expandir-contrair — da #325.)
--
-- Causa: o prefixo de resultado é PROTOCOLO entre as tools e o harness: quem consome
-- lê o prefixo para decidir se a ferramenta falhou. O lote 1 do #325 trocou os símbolos
-- por palavras em ui/, channels/ e providers/, mas os produtores de agent/ e tools/
-- ainda emitem símbolo. Enquanto os dois formatos coexistem, cada consumidor precisa
-- aceitar os DOIS; ler o prefixo cru em cada consumidor é o que faz a falha virar
-- sucesso EM SILÊNCIO quando um lado muda antes do outro (sem exceção e sem log).
--
-- Este spec prova quatro coisas:
--   1. o helper (lib/result.lua) reconhece os dois formatos nas 3 famílias;
--   2. o comportamento de hoje com o formato antigo foi preservado (inclusive na
--      extração do corpo da mensagem, em tools/error_feedback/post_exec.lua);
--   3. os consumidores migrados leem o prefixo SÓ pelo helper — nenhum `match("^❌")`
--      cru volta a aparecer num consumidor (é a prova de sensibilidade da issue);
--   4. cada PRODUTOR emite o formato do seu lote: agent/ já migrou (lote 2 do #325);
--      lib/ e tools/ ainda emitem o símbolo, e só saem no D6 (fim do formato antigo).
--
-- A integração do fallback da busca depois da migração de tools/web.lua continua
-- coberta por tests/web_search_fallback_spec.lua (#338).
--
-- Estado esperado ANTES da correção: FALHA (lib/result.lua não existe).

local RAIZ = (arg[0] or ""):match("^(.-)tests/")
if not RAIZ or RAIZ == "" then RAIZ = "." end
package.path = RAIZ .. "/?.lua;" .. package.path

local pass, fail = 0, 0

local function TEST(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

local function SEC(title)
  print("\n=== " .. title .. " ===")
end

local function ler(rel)
  local f = io.open(RAIZ .. "/" .. rel, "rb")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

-- 0. O helper precisa existir e ser alcançável por require("lib.result") tanto no
--    runtime (main.lua põe BASE/?.lua no package.path) quanto no spec (./?.lua).
SEC('0. lib/result.lua carrega por require("lib.result")')
local ok_req, resultado = pcall(require, "lib.result")
if not ok_req then
  print('  FAIL: lib/result.lua não carrega — ' .. tostring(resultado))
  print(string.format("\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══", pass, fail + 1, pass + fail + 1))
  os.exit(1)
end
TEST("lib/result.lua carrega", type(resultado) == "table")
TEST("expõe e_falha", type(resultado.e_falha) == "function")
TEST("expõe e_vazio", type(resultado.e_vazio) == "function")
TEST("expõe e_busca_vazia", type(resultado.e_busca_vazia) == "function")
TEST("expõe e_nao_util", type(resultado.e_nao_util) == "function")
TEST("expõe sucesso", type(resultado.sucesso) == "function")
TEST("expõe mensagem", type(resultado.mensagem) == "function")

-- 1. FALHA
SEC("1. Família FALHA: símbolo antigo e palavra nova")
TEST("símbolo, com corpo", resultado.e_falha("❌ Erro: x") == true)
TEST("palavra, com corpo", resultado.e_falha("[FAIL] Erro: x") == true)
TEST("símbolo, sem corpo", resultado.e_falha("❌") == true)
TEST("palavra, sem corpo", resultado.e_falha("[FAIL]") == true)
TEST("precedido de espaço não conta (hoje é ancorado no início)", resultado.e_falha(" ❌ Erro") == false)
TEST("no meio do texto não conta", resultado.e_falha("log: ❌ Erro") == false)
TEST("saída normal não é falha", resultado.e_falha("Resultado ok") == false)
TEST("string vazia não é falha", resultado.e_falha("") == false)
TEST("nil não é falha", resultado.e_falha(nil) == false)
TEST("número não é falha", resultado.e_falha(42) == false)

SEC("1b. sucesso: espelho de e_falha, fail-closed")
TEST("símbolo não é sucesso", resultado.sucesso("❌ x") == false)
TEST("palavra não é sucesso", resultado.sucesso("[FAIL] x") == false)
TEST("saída normal é sucesso", resultado.sucesso("ok") == true)
TEST("string vazia é sucesso (hoje, not match é true em vazio)", resultado.sucesso("") == true)
TEST("nil não é sucesso (fail-closed: nunca inventar sucesso)", resultado.sucesso(nil) == false)

-- 2. VAZIO
SEC("2. Família VAZIO: símbolo antigo e palavra nova")
TEST("símbolo", resultado.e_vazio("📭 Nenhum arquivo de memória encontrado") == true)
TEST("palavra", resultado.e_vazio("[EMPTY] Nenhum arquivo de memória encontrado") == true)
TEST("símbolo, sem corpo", resultado.e_vazio("📭") == true)
TEST("no meio do texto não conta", resultado.e_vazio("aviso: 📭 vazio") == false)
TEST("lista com conteúdo não é vazio", resultado.e_vazio("📁 3 arquivos") == false)
TEST("nil não é vazio", resultado.e_vazio(nil) == false)

-- 3. BUSCA SEM RESULTADO
SEC("3. Família BUSCA SEM RESULTADO: símbolo antigo e palavra nova")
TEST("símbolo (grep)", resultado.e_busca_vazia("🔍 Nenhum resultado encontrado para o padrão: 'x'") == true)
TEST("palavra (grep)", resultado.e_busca_vazia("[SEARCH] Nenhum resultado encontrado para o padrão: 'x'") == true)
TEST("variante Nenhuma entra na família (memória)", resultado.e_busca_vazia("🔍 Nenhuma memória encontrada para: \"x\"") == true)
TEST("palavra com Nenhuma", resultado.e_busca_vazia("[SEARCH] Nenhuma memória encontrada") == true)
TEST("resultado real não é busca vazia", resultado.e_busca_vazia("[SEARCH] Resultado: lua\n• https://lua.org") == false)
TEST("falha do provedor não é busca vazia", resultado.e_busca_vazia("[FAIL] Busca bloqueada") == false)
TEST("nil não é busca vazia", resultado.e_busca_vazia(nil) == false)

SEC("3b. e_busca_vazia com detalhe: preserva o critério estrito de tools/web.lua")
TEST("símbolo + detalhe", resultado.e_busca_vazia("🔍 Nenhum resultado", "resultado") == true)
TEST("palavra + detalhe", resultado.e_busca_vazia("[SEARCH] Nenhum resultado para: lua", "resultado") == true)
TEST("detalhe ausente derruba o caso (não confunde outro Nenhum)",
  resultado.e_busca_vazia("❌ Nenhum provedor de busca disponível.", "resultado") == false)

-- 4. NÃO ÚTIL (filtro da injeção de memória em agent/loop/system_messages.lua)
SEC("4. e_nao_util: as 3 famílias nos 2 formatos")
local FORMAS = {
  "❌ erro na busca", "[FAIL] erro na busca",
  "📭 Nenhum arquivo de memória encontrado", "[EMPTY] Nenhum arquivo de memória encontrado",
  "🔍 Nenhum resultado encontrado", "[SEARCH] Nenhum resultado encontrado",
}
for i, s in ipairs(FORMAS) do
  TEST("inútil (forma " .. i .. ")", resultado.e_nao_util(s) == true)
end
TEST("memória real passa", resultado.e_nao_util("[[TermAI]] o núcleo fica em ~/TermAI/") == false)
TEST("string vazia passa (como hoje)", resultado.e_nao_util("") == false)
TEST("nil não é inútil (como hoje: mem nil já barrava antes)", resultado.e_nao_util(nil) == false)

-- 5. MENSAGEM (corpo sem o prefixo)
SEC("5. mensagem: corpo sem o prefixo, igual ao de hoje")
TEST("prefixo antigo", resultado.mensagem("❌ command not found") == "command not found")
TEST("prefixo novo", resultado.mensagem("[FAIL] command not found") == "command not found")
TEST("prefixo colado ao corpo", resultado.mensagem("❌erro") == "erro")
TEST("espaços das pontas são aparados", resultado.mensagem("❌  erro  ") == "erro")
TEST("sem prefixo volta intacto", resultado.mensagem("saida normal") == "saida normal")
TEST("só o prefixo devolve vazio (igual a hoje)", resultado.mensagem("❌") == "")
TEST("nil volta nil", resultado.mensagem(nil) == nil)

-- 6. CONSUMIDOR REAL (formato novo era invisível: devolvia nil, sem feedback)
SEC("6. Consumidor real: tools/error_feedback/post_exec.lua")
local post = require("tools.error_feedback.post_exec")

local smart_novo = post.analyze("Exec", "ls x", "[FAIL] command not found")
TEST("formato novo (palavra) gera feedback", smart_novo ~= nil)
TEST("formato novo: feedback classifica o erro",
  type(smart_novo) == "string" and smart_novo:find("Comando nao encontrado", 1, true) ~= nil)
TEST("formato novo: feedback mostra o corpo sem o prefixo",
  type(smart_novo) == "string" and smart_novo:find("command not found", 1, true) ~= nil)
TEST("formato novo: feedback não deixa o prefixo cru (corpo já sem o prefixo do input)",
  type(smart_novo) == "string"
    and smart_novo:find("\n  [FAIL] command not found\n", 1, true) ~= nil
    and smart_novo:find("[FAIL] [FAIL]", 1, true) == nil)

local smart_velho = post.analyze("Exec", "ls x", "❌ command not found")
TEST("formato antigo (símbolo) continua gerando feedback", smart_velho ~= nil)
TEST("formato antigo e novo produzem o mesmo texto", smart_velho == smart_novo)
TEST("saída normal: sem feedback", post.analyze("Exec", "ls", "arquivo.txt") == nil)
TEST("result nil: sem feedback", post.analyze("Exec", "ls", nil) == nil)

-- 7. NENHUM CONSUMIDOR LÊ O PREFIXO CRU (prova de sensibilidade da issue:
--    reintroduzir um match("^❌") num consumidor derruba este bloco)
SEC("7. Prova de sensibilidade: o prefixo é lido só pelo helper")
local CONSUMIDORES = {
  "agent/loop/system_messages.lua",
  "agent/loop/tool_runner/executor/nucleo_2.lua",
  "agent/loop/tool_runner/executor/nucleo_3.lua",
  "agent/startup/parte_1.lua",
  "agent/tools_handler/executor.lua",
  "tools/error_feedback/post_exec.lua",
  "tools/web.lua",
}
local CRUS = {
  'match("^❌',
  'match("^📭',
  'match("^🔍',
  'match("🔍 Nenhum',
  'match("%[SEARCH%] Nenhum',
  'match("^%[FAIL%]"',
}
for _, rel in ipairs(CONSUMIDORES) do
  local src = ler(rel)
  TEST("consumidor existe: " .. rel, src ~= nil, "não encontrado a partir de " .. RAIZ)
  if src then
    TEST("requer o helper: " .. rel, src:find('require("lib.result")', 1, true) ~= nil)
    local cru = nil
    for _, pat in ipairs(CRUS) do
      if src:find(pat, 1, true) then cru = pat break end
    end
    TEST("lê o prefixo só pelo helper: " .. rel, cru == nil, cru and ("ainda há " .. cru) or nil)
  end
end

-- 8. PRODUTORES: cada um emite o formato do seu lote
-- (o lote 2 do #325 migrou os produtores de agent/ e o lote 3 migrou os de tools/ para
--  a palavra [FAIL]/[EMPTY]/[SEARCH]; só lib/tools/chamada.lua segue no símbolo —
--  a remoção do formato antigo do contrato é o D6.)
SEC("8. Produtores: emitem o formato do seu lote (agent/ e tools/ migrados; lib/ ainda simbolo)")
local PRODUTORES = {
  { "lib/tools/chamada.lua",                        'return "❌ Erro: Sintaxe inválida."' },
  { "agent/loop/tool_runner/executor/nucleo_2.lua", '"[FAIL] Action cancelled by user."' },
  { "agent/loop/tool_runner/executor/nucleo_3.lua", '"[FAIL] Action cancelled by user."' },
  { "tools/memory.lua",                             '"[EMPTY] Nenhum arquivo de memória' },
  { "tools/grep/formatter.lua",                     '"[SEARCH] Nenhum resultado encontrado' },
}
for _, p in ipairs(PRODUTORES) do
  local src = ler(p[1])
  TEST("produtor emite o formato esperado: " .. p[1],
    src ~= nil and src:find(p[2], 1, true) ~= nil, "esperado: " .. p[2])
end

print(string.format("\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══", pass, fail, pass + fail))

if fail > 0 then
  os.exit(1)
end
