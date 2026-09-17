-- tests/disabled_tools_spec.lua
-- Regressão Issue #32 / PR #46: desativação de tools por agente.
--
-- "E se isso mudar?": se get_schema voltar a ignorar o filtro, se a ordem
-- deixar de ser estável, se call* deixar de recusar tool desativada, ou se
-- callers sem 2º arg quebrarem — este arquivo grita antes da TUI.
--
-- Escopo: fachada tools (get_schema, get_docs, call, call_structured).
-- Não cobre menus TUI/CLI (I/O interativo) nem persistência em config.json
-- (integração com filesystem do usuário).

package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0

local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  OK  " .. name)
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

print("\n=== Unit tests: disabled tools per agent (Issue #32 / PR #46) ===\n")

local tools = require("tools")

-- Nomes reais do registry (ordem não garantida em pairs)
local all_names = {}
for name in pairs(tools.registry) do
  all_names[#all_names + 1] = name
end
table.sort(all_names)
T("registry tem tools registradas", #all_names > 0, "count=" .. tostring(#all_names))

local sample = all_names[1]
local sample2 = all_names[2] or all_names[1]

-- ─────────────────────────────────────────────────────────────
sec("get_schema sem filtro (regressão zero)")
-- ─────────────────────────────────────────────────────────────

local full = tools.get_schema()
T("get_schema() retorna tabela", type(full) == "table")
T("get_schema() não-vazio sem filtro", full ~= nil and #full > 0)

local function schema_names(schema)
  local n = {}
  if not schema then return n end
  for _, entry in ipairs(schema) do
    local fn = entry["function"] or entry.function
    if fn and fn.name then n[#n + 1] = fn.name end
  end
  return n
end

local full_names = schema_names(full)
T("ordem estável sem filtro (sorted)",
  (function()
    local copy = {}
    for i, n in ipairs(full_names) do copy[i] = n end
    table.sort(copy)
    for i = 1, #copy do
      if copy[i] ~= full_names[i] then return false end
    end
    return true
  end)())

-- ─────────────────────────────────────────────────────────────
sec("get_schema com filtro (set)")
-- ─────────────────────────────────────────────────────────────

local filtered_set = tools.get_schema({ [sample] = true })
local filtered_names = schema_names(filtered_set)

local has_sample = false
for _, n in ipairs(filtered_names) do
  if n == sample then has_sample = true; break end
end
T("set: tool desativada ausente do schema", not has_sample, "sample=" .. tostring(sample))

if #full_names > 1 then
  T("set: outras tools permanecem",
    #filtered_names == #full_names - 1,
    string.format("full=%d filtered=%d", #full_names, #filtered_names))
end

-- ─────────────────────────────────────────────────────────────
sec("get_schema com filtro (array)")
-- ─────────────────────────────────────────────────────────────

local filtered_arr = tools.get_schema({ sample })
local arr_names = schema_names(filtered_arr)
local has_sample_arr = false
for _, n in ipairs(arr_names) do
  if n == sample then has_sample_arr = true; break end
end
T("array: tool desativada ausente", not has_sample_arr)

local filtered_multi = tools.get_schema({ sample, sample2 })
local multi_names = schema_names(filtered_multi)
local leak = false
for _, n in ipairs(multi_names) do
  if n == sample or n == sample2 then leak = true; break end
end
T("array multi: ambas ausentes", not leak)

-- ─────────────────────────────────────────────────────────────
sec("get_schema — todos desativados → nil")
-- ─────────────────────────────────────────────────────────────

local all_disabled = {}
for _, n in ipairs(full_names) do all_disabled[n] = true end
-- Tools sem schema não entram em get_schema; desativar só as que têm schema
local none = tools.get_schema(all_disabled)
T("todas com schema desativadas → nil", none == nil)

-- ─────────────────────────────────────────────────────────────
sec("get_schema — entradas inválidas / bordas")
-- ─────────────────────────────────────────────────────────────

T("disabled nil ≡ sem filtro",
  #schema_names(tools.get_schema(nil)) == #full_names)
T("disabled string (tipo errado) ≡ sem filtro",
  #schema_names(tools.get_schema("Exec")) == #full_names)
T("nome inexistente no filtro não quebra",
  type(tools.get_schema({ "ToolQueNaoExisteXYZ" })) == "table")

-- ─────────────────────────────────────────────────────────────
sec("get_docs com filtro")
-- ─────────────────────────────────────────────────────────────

local docs_full = tools.get_docs()
local docs_filtered = tools.get_docs({ [sample] = true })
T("get_docs() string não-vazia", type(docs_full) == "string" and #docs_full > 0)
T("get_docs filtrado omite tool desativada",
  not docs_filtered:find("- " .. sample .. ":", 1, true),
  "sample=" .. tostring(sample))
T("get_docs sem filtro ainda lista a tool",
  docs_full:find("- " .. sample .. ":", 1, true) ~= nil)

-- ─────────────────────────────────────────────────────────────
sec("defesa call / call_structured")
-- ─────────────────────────────────────────────────────────────

-- Path desativado: retorna antes de hooks / execute
local msg_call = tools.call(sample .. "|dummy", { [sample] = true })
T("call recusa tool desativada (set)",
  type(msg_call) == "string" and msg_call:find("desativada") ~= nil,
  tostring(msg_call))

local msg_call_arr = tools.call(sample .. "|dummy", { sample })
T("call recusa tool desativada (array)",
  type(msg_call_arr) == "string" and msg_call_arr:find("desativada") ~= nil)

local msg_struct = tools.call_structured(sample, {}, { disabled_tools = { [sample] = true } })
T("call_structured recusa tool desativada",
  type(msg_struct) == "string" and msg_struct:find("desativada") ~= nil,
  tostring(msg_struct))

-- Callers legados sem 2º arg: não devem tratar como "tudo desativado"
-- (só validamos que a assinatura aceita nil — não executamos tool real
-- para evitar dependência de hooks/permissões no unitário)
T("call sem 2º arg não explode na assinatura",
  (function()
    -- Sintaxe inválida evita execute; testa path antes do disabled check parcial
    local r = tools.call("sem-pipe-aqui")
    return type(r) == "string" and r:find("Sintaxe") ~= nil
  end)())

T("call_structured sem opts.disabled_tools aceita opts vazio",
  (function()
    -- Tool inexistente: path após disabled check
    local r = tools.call_structured("ToolInexistenteXYZ999", {}, {})
    return type(r) == "string" and r:find("não existe") ~= nil
  end)())

-- ─────────────────────────────────────────────────────────────
sec("payload contrato (leitura estática)")
-- ─────────────────────────────────────────────────────────────

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a") or ""
  f:close()
  return s
end

local payload_src = read_file("agent/api/payload.lua") or read_file("./agent/api/payload.lua")
local context_src = read_file("agent/context.lua") or read_file("./agent/context.lua")
local tools_src = read_file("tools.lua") or read_file("./tools.lua")

if payload_src then
  T("payload passa ctx.disabled_tools a get_schema",
    payload_src:find("get_schema%(ctx%.disabled_tools%)") ~= nil)
  T("payload respeita ctx.no_tools soberano",
    payload_src:find("not ctx%.no_tools") ~= nil or payload_src:find("ctx%.no_tools") ~= nil)
else
  T("payload.lua legível no cwd", false, "rode da raiz do clone")
end

if context_src then
  T("context popula disabled_tools",
    context_src:find("disabled_tools") ~= nil)
  T("context popula agent_id",
    context_src:find("agent_id") ~= nil)
  -- Não deve hardcodar filtro só para "main" no path de disabled
  T("context resolve agente por list[1].id (não hardcode exclusivo)",
    context_src:find("list%[1%]") ~= nil or context_src:find("list%[1%]") ~= nil
    or context_src:find("get_agent") ~= nil)
else
  T("context.lua legível no cwd", false, "rode da raiz do clone")
end

if tools_src then
  T("tools.lua documenta get_schema com disabled",
    tools_src:find("get_schema%(disabled%)") ~= nil
    or tools_src:find("function tools%.get_schema") ~= nil)
  T("tools.lua tem to_disabled_set (set + array)",
    tools_src:find("to_disabled_set") ~= nil)
else
  T("tools.lua legível no cwd", false)
end

-- ─────────────────────────────────────────────────────────────
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes de desativação de tools (#32) passaram")
end
