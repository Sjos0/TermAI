-- tests/lib_result_spec.lua
-- #343 — Helper único de resultado: a leitura do prefixo num ponto só.
-- #352 (D6 do #325) — contração: o formato antigo (símbolo) saiu.
--
-- Causa: o prefixo de resultado é PROTOCOLO entre as tools e o harness: quem consome
-- lê o prefixo para decidir se a ferramenta falhou. O lote 1 do #325 trocou os símbolos
-- por palavras em ui/, channels/ e providers/; os lotes 2 a 4 fizeram o mesmo em
-- agent/, tools/ e commands/. Ler o prefixo cru em cada consumidor é o que faz a falha
-- virar sucesso EM SILÊNCIO quando um lado muda antes do outro (sem exceção e sem log).
--
-- Este spec prova quatro coisas:
--   1. o helper (lib/result.lua) reconhece o formato NOVO nas 3 famílias;
--   2. o formato ANTIGO já não é reconhecido em família nenhuma — é o contrato do D6:
--      se alguém reintroduzir a leitura do símbolo no helper, estes casos falham;
--   3. os consumidores leem o prefixo SÓ pelo helper — nenhum `match("^❌")` cru volta
--      a aparecer num consumidor (prova de sensibilidade da issue);
--   4. cada PRODUTOR emite o formato novo (todos os lotes do #325 estão fechados).
--
-- A integração do fallback da busca fica em tests/web_search_fallback_spec.lua (#338);
-- a ausência de símbolos nos diretórios de produção em tests/status_sem_simbolo_spec.lua (#352).

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

-- 1. FALHA (formato novo)
SEC("1. Família FALHA: só a palavra [FAIL]")
TEST("palavra, com corpo", resultado.e_falha("[FAIL] Erro: x") == true)
TEST("palavra, sem corpo", resultado.e_falha("[FAIL]") == true)
TEST("precedido de espaço não conta (ancorado no início)", resultado.e_falha(" [FAIL] Erro") == false)
TEST("no meio do texto não conta", resultado.e_falha("log: [FAIL] Erro") == false)
TEST("saída normal não é falha", resultado.e_falha("Resultado ok") == false)
TEST("string vazia não é falha", resultado.e_falha("") == false)
TEST("nil não é falha", resultado.e_falha(nil) == false)
TEST("número não é falha", resultado.e_falha(42) == false)

SEC("1b. Contrato do D6: o símbolo antigo NÃO é mais reconhecido (as 3 famílias)")
TEST("símbolo de falha não é falha", resultado.e_falha("❌ Erro: x") == false)
TEST("símbolo de falha sozinho não é falha", resultado.e_falha("❌") == false)
TEST("símbolo ✗ não é falha", resultado.e_falha("✗ falhou") == false)
TEST("símbolo de vazio não é vazio", resultado.e_vazio("📭 Nenhum arquivo") == false)
TEST("símbolo de busca não é busca vazia", resultado.e_busca_vazia("🔍 Nenhum resultado") == false)
TEST("e_nao_util não filtra mais o formato antigo", resultado.e_nao_util("❌ erro na busca") == false)
-- Consequência assumida do D6: dado histórico (sessão gravada antes da migração) com
-- símbolo não é mais apresentado como falha pelo replay — ver risco residual na #352.
TEST("dado histórico com símbolo passa como sucesso (consequência do D6)",
  resultado.sucesso("❌ Erro: x") == true)

SEC("1c. sucesso: espelho de e_falha, fail-closed")
TEST("palavra não é sucesso", resultado.sucesso("[FAIL] x") == false)
TEST("saída normal é sucesso", resultado.sucesso("ok") == true)
TEST("string vazia é sucesso (hoje, not match é true em vazio)", resultado.sucesso("") == true)
TEST("nil não é sucesso (fail-closed: nunca inventar sucesso)", resultado.sucesso(nil) == false)

-- 2. VAZIO
SEC("2. Família VAZIO: só a palavra [EMPTY]")
TEST("palavra", resultado.e_vazio("[EMPTY] Nenhum arquivo de memória encontrado") == true)
TEST("palavra, sem corpo", resultado.e_vazio("[EMPTY]") == true)
TEST("no meio do texto não conta", resultado.e_vazio("aviso: [EMPTY] vazio") == false)
TEST("lista com conteúdo não é vazio", resultado.e_vazio("[DIR] 3 arquivos") == false)
TEST("nil não é vazio", resultado.e_vazio(nil) == false)

-- 3. BUSCA SEM RESULTADO
SEC("3. Família BUSCA SEM RESULTADO: só a palavra [SEARCH] Nenhum")
TEST("palavra (grep)", resultado.e_busca_vazia("[SEARCH] Nenhum resultado encontrado para o padrão: 'x'") == true)
TEST("palavra com Nenhuma (memória)", resultado.e_busca_vazia("[SEARCH] Nenhuma memória encontrada para: \"x\"") == true)
TEST("resultado real não é busca vazia", resultado.e_busca_vazia("[SEARCH] Resultado: lua\n• https://lua.org") == false)
TEST("falha do provedor não é busca vazia", resultado.e_busca_vazia("[FAIL] Busca bloqueada") == false)
TEST("nil não é busca vazia", resultado.e_busca_vazia(nil) == false)

SEC("3b. e_busca_vazia com detalhe: preserva o critério estrito de tools/web.lua")
TEST("palavra + detalhe", resultado.e_busca_vazia("[SEARCH] Nenhum resultado", "resultado") == true)
TEST("palavra + detalhe com sufixo", resultado.e_busca_vazia("[SEARCH] Nenhum resultado para: lua", "resultado") == true)
TEST("detalhe ausente derruba o caso (não confunde outro Nenhum)",
  resultado.e_busca_vazia("[FAIL] Nenhum provedor de busca disponível.", "resultado") == false)

-- 4. NÃO ÚTIL (filtro da injeção de memória em agent/loop/system_messages.lua)
SEC("4. e_nao_util: as 3 famílias no formato novo")
local FORMAS = {
  "[FAIL] erro na busca",
  "[EMPTY] Nenhum arquivo de memória encontrado",
  "[SEARCH] Nenhum resultado encontrado",
}
for i, s in ipairs(FORMAS) do
  TEST("inútil (forma " .. i .. ")", resultado.e_nao_util(s) == true)
end
TEST("memória real passa", resultado.e_nao_util("[[TermAI]] o núcleo fica em ~/TermAI/") == false)
TEST("string vazia passa (como hoje)", resultado.e_nao_util("") == false)
TEST("nil não é inútil (como hoje: mem nil já barrava antes)", resultado.e_nao_util(nil) == false)

-- 5. MENSAGEM (corpo sem o prefixo)
SEC("5. mensagem: corpo sem o prefixo, igual ao de hoje")
TEST("prefixo novo", resultado.mensagem("[FAIL] command not found") == "command not found")
TEST("prefixo colado ao corpo", resultado.mensagem("[FAIL]erro") == "erro")
TEST("espaços das pontas são aparados", resultado.mensagem("[FAIL]  erro  ") == "erro")
TEST("sem prefixo volta intacto", resultado.mensagem("saida normal") == "saida normal")
TEST("só o prefixo devolve vazio (igual a hoje)", resultado.mensagem("[FAIL]") == "")
TEST("formato antigo não é mais aparado (símbolo saiu do contrato)",
  resultado.mensagem("❌ command not found") == "❌ command not found")
TEST("nil volta nil", resultado.mensagem(nil) == nil)

-- 6. CONSUMIDOR REAL
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

TEST("formato antigo (símbolo) já não gera feedback (saiu do contrato)",
  post.analyze("Exec", "ls x", "❌ command not found") == nil)
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

-- 8. PRODUTORES: todos no formato novo (o D6 fechou o último, lib/tools/chamada.lua)
SEC("8. Produtores: emitem o formato novo ([FAIL]/[EMPTY]/[SEARCH])")
local PRODUTORES = {
  { "lib/tools/chamada.lua",                        'return "[FAIL] Erro: Sintaxe inválida."' },
  { "lib/tools/chamada.lua",                        'return "[FAIL] Ferramenta \'" .. t_name' },
  { "agent/loop/tool_runner/executor/nucleo_2.lua", '"[FAIL] Action cancelled by user."' },
  { "agent/loop/tool_runner/executor/nucleo_3.lua", '"[FAIL] Action cancelled by user."' },
  { "tools/memory.lua",                             '"[EMPTY] Nenhum arquivo de memória' },
  { "tools/grep/formatter.lua",                     '"[SEARCH] Nenhum resultado encontrado' },
}
for _, p in ipairs(PRODUTORES) do
  local src = ler(p[1])
  TEST("produtor emite o formato esperado: " .. p[1] .. " -> " .. p[2],
    src ~= nil and src:find(p[2], 1, true) ~= nil, "esperado: " .. p[2])
end

print(string.format("\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══", pass, fail, pass + fail))

if fail > 0 then
  os.exit(1)
end
