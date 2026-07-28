-- tests/benchmark_bolt.lua
-- Benchmark comparativo para as otimizações do Bolt.

-- Define as funções antigas (não otimizadas) para comparação direta
local function old_strip_tool_xml(s)
  if not s then return "" end
  local flat = s:gsub("\n", "\0")
  flat = flat:gsub("<tool>.-</tool>",           "")
  flat = flat:gsub("<tool_call>.-</tool_call>", "")
  flat = flat:gsub("</?tool[_a-zA-Z]*>\0*",     "")
  flat = flat:gsub("</?name>\0*",               "")
  flat = flat:gsub("</?arg[a-z_]*>\0*",         "")
  flat = flat:gsub("</?arguments>\0*",          "")
  flat = flat:gsub("</function>\0*",            "")
  flat = flat:gsub("\0+",                       "\n")
  return flat:match("^%s*(.-)%s*$") or ""
end

local function old_strip_thinking_tags(text)
  if not text then return text end
  text = text:gsub("<[Tt]hink[^>]*>.-</[Tt]hink>", "")
  text = text:gsub("<[Tt]hought[^>]*>.-</[Tt]hought>", "")
  return text
end

-- Carrega as versões novas otimizadas
package.path = "./?.lua;./?/init.lua;" .. package.path
local xml_cleaner = require("agent.startup.xml_cleaner")
local utils = require("agent.api.utils")

local new_strip_tool_xml = xml_cleaner.strip_tool_xml
local new_strip_thinking_tags = utils.strip_thinking_tags

-- Textos para teste
local plain_text_short = "Olá, tudo bem? Como posso ajudar você hoje com seus projetos?"
local plain_text_long = string.rep("Este é um texto bem longo sem qualquer tag xml ou tags de pensamento para simular mensagens de chat reais. ", 50)

local with_tags_xml = "<tool><name>exec</name><arg>ls -la</arg></tool> Algum texto após."
local with_tags_think = "<think>Estou pensando sobre o problema de otimização de strings.</think> Olá mundo!"

local iterations = 50000

print("==================================================================")
print("             BENCHMARK DE PERFORMANCE — BOLT ⚡")
print("==================================================================")

-- Benchmark: strip_tool_xml (Texto Curto)
local start_time = os.clock()
for i = 1, iterations do
  old_strip_tool_xml(plain_text_short)
end
local old_tool_short_time = os.clock() - start_time

start_time = os.clock()
for i = 1, iterations do
  new_strip_tool_xml(plain_text_short)
end
local new_tool_short_time = os.clock() - start_time

-- Benchmark: strip_tool_xml (Texto Longo)
start_time = os.clock()
for i = 1, iterations do
  old_strip_tool_xml(plain_text_long)
end
local old_tool_long_time = os.clock() - start_time

start_time = os.clock()
for i = 1, iterations do
  new_strip_tool_xml(plain_text_long)
end
local new_tool_long_time = os.clock() - start_time


-- Benchmark: strip_thinking_tags (Texto Curto)
start_time = os.clock()
for i = 1, iterations do
  old_strip_thinking_tags(plain_text_short)
end
local old_think_short_time = os.clock() - start_time

start_time = os.clock()
for i = 1, iterations do
  new_strip_thinking_tags(plain_text_short)
end
local new_think_short_time = os.clock() - start_time

-- Benchmark: strip_thinking_tags (Texto Longo)
start_time = os.clock()
for i = 1, iterations do
  old_strip_thinking_tags(plain_text_long)
end
local old_think_long_time = os.clock() - start_time

start_time = os.clock()
for i = 1, iterations do
  new_strip_thinking_tags(plain_text_long)
end
local new_think_long_time = os.clock() - start_time


-- Verificação de corretude
assert(old_strip_tool_xml(plain_text_short) == new_strip_tool_xml(plain_text_short), "Erro de corretude em strip_tool_xml curto")
assert(old_strip_tool_xml(plain_text_long) == new_strip_tool_xml(plain_text_long), "Erro de corretude em strip_tool_xml longo")
assert(old_strip_tool_xml(with_tags_xml) == new_strip_tool_xml(with_tags_xml), "Erro de corretude em strip_tool_xml com tags")

assert(old_strip_thinking_tags(plain_text_short) == new_strip_thinking_tags(plain_text_short), "Erro de corretude em strip_thinking_tags curto")
assert(old_strip_thinking_tags(plain_text_long) == new_strip_thinking_tags(plain_text_long), "Erro de corretude em strip_thinking_tags longo")
assert(old_strip_thinking_tags(with_tags_think) == new_strip_thinking_tags(with_tags_think), "Erro de corretude em strip_thinking_tags com tags")

print("Resultados do Benchmark (" .. iterations .. " iterações):")
print(string.format("1. strip_tool_xml (Texto Curto):"))
print(string.format("   • Antigo: %.4f s", old_tool_short_time))
print(string.format("   • Novo:   %.4f s", new_tool_short_time))
print(string.format("   • Ganho:  %.2f%% (Melhora de %.1fx)", (old_tool_short_time - new_tool_short_time) / old_tool_short_time * 100, old_tool_short_time / new_tool_short_time))

print(string.format("2. strip_tool_xml (Texto Longo):"))
print(string.format("   • Antigo: %.4f s", old_tool_long_time))
print(string.format("   • Novo:   %.4f s", new_tool_long_time))
print(string.format("   • Ganho:  %.2f%% (Melhora de %.1fx)", (old_tool_long_time - new_tool_long_time) / old_tool_long_time * 100, old_tool_long_time / new_tool_long_time))

print(string.format("3. strip_thinking_tags (Texto Curto):"))
print(string.format("   • Antigo: %.4f s", old_think_short_time))
print(string.format("   • Novo:   %.4f s", new_think_short_time))
print(string.format("   • Ganho:  %.2f%% (Melhora de %.1fx)", (old_think_short_time - new_think_short_time) / old_think_short_time * 100, old_think_short_time / new_think_short_time))

print(string.format("4. strip_thinking_tags (Texto Longo):"))
print(string.format("   • Antigo: %.4f s", old_think_long_time))
print(string.format("   • Novo:   %.4f s", new_think_long_time))
print(string.format("   • Ganho:  %.2f%% (Melhora de %.1fx)", (old_think_long_time - new_think_long_time) / old_think_long_time * 100, old_think_long_time / new_think_long_time))

print("==================================================================")
print("✅ Todos os testes de corretude passaram com sucesso!")
print("==================================================================")
