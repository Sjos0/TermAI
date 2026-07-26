-- tests/test_depth_tracker.lua — Testes robustos e de performance para o depth_tracker.
-- Executar: HOME="/app" lua5.4 tests/test_depth_tracker.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name)
  end
end

local function sec(t) print("\n=== " .. t .. " ===") end

-- Importar o depth_tracker e o parser completo para testar a integração.
local depth_tracker = require("ui.thinking_parser.depth_tracker")
local thinking_parser = require("ui.thinking_parser")

-- ═══════ 1. TESTES UNITÁRIOS DO DEPTH_TRACKER (CORRETUDE) ═══════
sec("1. Corretude do depth_tracker")

-- Caso 1: Bloco simples sem aninhamento
depth_tracker.reset()
T("Unitário: Bloco simples completo", depth_tracker.find_matching_close("content </tool>") == 9)

-- Caso 2: Bloco com tag incompleta (chega em partes)
depth_tracker.reset()
T("Unitário: Tag incompleta parte 1", depth_tracker.find_matching_close("content </to") == nil)
T("Unitário: Tag incompleta parte 2", depth_tracker.find_matching_close("content </tool>") == 9)

-- Caso 3: Bloco com aninhamento simples
depth_tracker.reset()
-- O primeiro </tool> fecha o interno, o segundo fecha o externo.
T("Unitário: Aninhado - primeiro fecho", depth_tracker.find_matching_close("inner <tool> code </tool> remaining") == nil)
T("Unitário: Aninhado - segundo fecho", depth_tracker.find_matching_close("inner <tool> code </tool> remaining </tool> extra") == 37)

-- Caso 4: Múltiplos aninhamentos profundos
depth_tracker.reset()
-- <tool> externo já consumido (profundidade inicial = 1).
-- Encontra <tool> -> depth=2.
-- Encontra <tool> -> depth=3.
-- Encontra </tool> -> depth=2.
-- Encontra </tool> -> depth=1.
-- Encontra </tool> -> depth=0 (fecho).
local nested_buf = "lvl2 <tool> lvl3 <tool> nested </tool> lvl3_end </tool> lvl2_end </tool> final"
T("Unitário: Aninhamento triplo completo", depth_tracker.find_matching_close(nested_buf) == 66)


-- ═══════ 2. TESTES DE INTEGRAÇÃO DO PARSER EM STREAM ═══════
sec("2. Integração com o thinking_parser")

local received_reasoning = {}
local received_tokens = {}

local function stream_reasoning(tok)
  table.insert(received_reasoning, tok)
end

local function stream_token(tok)
  table.insert(received_tokens, tok)
end

local function clear_received()
  received_reasoning = {}
  received_tokens = {}
end

-- Caso 1: Processamento de bloco simples em pedaços
thinking_parser.reset()
clear_received()

thinking_parser.feed("Texto inicial <to", stream_reasoning, stream_token)
T("Integração: <to não ativa tool", #received_tokens == 1 and received_tokens[1] == "Texto inicial ")

thinking_parser.feed("ol> corpo do tool </tool> pós-tool", stream_reasoning, stream_token)
T("Integração: corpo do tool emitido", received_tokens[2] == "<tool>")
T("Integração: conteúdo do tool emitido", received_tokens[3] == " corpo do tool ")
T("Integração: </tool> emitido", received_tokens[4] == "</tool>")
T("Integração: conteúdo pós-tool emitido", received_tokens[5] == " pós-tool")


-- ═══════ 3. TESTE ROBUSTO ADVERSARIAL (STRESS & CORRETUDE) ═══════
sec("3. Testes Adversariais")

thinking_parser.reset()
clear_received()

-- Enviar múltiplos blocos fragmentados e aninhados misturados com thinking
local chunks = {
  "Olá, ",
  "vou usar uma ferramenta. ",
  "<tool>",
  "gerar_imagem(prompt='<tool> nested </tool>')",
  "</tool>",
  " e agora voy pensar: <think>",
  "Estou pensando ",
  "profundamente ",
  "</think> Fim."
}

for _, chunk in ipairs(chunks) do
  thinking_parser.feed(chunk, stream_reasoning, stream_token)
end

local full_tokens = table.concat(received_tokens, "")
local full_reasoning = table.concat(received_reasoning, "")

T("Adversarial: Tokens contêm o conteúdo esperado", full_tokens:match("gerar_imagem") ~= nil)
T("Adversarial: Tags de tool preservadas", full_tokens:match("<tool>gerar_imagem") ~= nil)
T("Adversarial: Pensamento capturado corretamente", full_reasoning == "Estou pensando profundamente ")
T("Adversarial: Texto final recebido como token", full_tokens:match("Fim%.") ~= nil)


-- ═══════ 4. MICRO-BENCHMARK DE PERFORMANCE O(N) ═══════
sec("4. Micro-benchmark de Performance (Escalabilidade)")

-- Geramos um buffer simulando uma resposta de ferramenta extremamente longa (ex: 200 mil caracteres),
-- e simulamos a chegada de novos tokens de 1 em 1 caractere no modo tool.
-- Sem a otimização (O(N²)), re-escanear esse buffer gigante a cada caractere demoraria muito.
-- Com a otimização (O(N)), cada chamada é instantânea pois o escaneamento resume do índice salvo.

depth_tracker.reset()
local huge_payload = string.rep("A", 100000) -- 100KB de payload
depth_tracker.find_matching_close(huge_payload) -- Primeiríssima busca, inicializa o índice

local start_time = os.clock()
for i = 1, 500 do
  huge_payload = huge_payload .. "B"
  depth_tracker.find_matching_close(huge_payload)
end
local duration = os.clock() - start_time

print(string.format("  Tempo para 500 buscas em buffer de 100KB+: %.4f segundos", duration))
T("Performance: O(N) garante tempo de execução extremamente baixo (< 0.1s)", duration < 0.1)


-- ═══════ RELATÓRIO DO SUITE DE TESTES ═══════
print("\n" .. string.rep("═", 60))
print(string.format("RESULTADO: %d passaram, %d falharam (total: %d)", pass, fail, pass + fail))
print(string.rep("═", 60))
if fail > 0 then os.exit(1) end
