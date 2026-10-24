package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/tools_descriptions_spec.lua — Lint das descrições das tools (em inglês, com as seções obrigatórias).
-- Regras (docs/plans/DESCRICOES_TOOLS_EN.md): nomes em inglês; descrição com "Use" (quando usar) e
-- "Do not"/"Never" (quando não usar); descrições e textos de parâmetros sem português.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local tools = require("tools")

-- Marcadores de português que não podem aparecer em descrição (nomes próprios de parâmetro são exceção).
local PT_MARKERS = {
  " não ", " para ", " que ", " uma ", " com ", " são ", "ção", " da ", " dos ", " das ",
  " sessão", " arquivo", " tarefa", " agente", " pelo ", " pela ", " ou ", " se ", " ao ",  -- ' do ' removido: falso positivo em "Do not"
}
local function has_pt(text)
  local t = " " .. text:lower() .. " "
  for _, m in ipairs(PT_MARKERS) do
    if t:find(m, 1, true) then return m end
  end
  return nil
end

-- Nomes antigos em português não podem estar registrados.
local OLD_NAMES = { "calcular", "sessoes_listar", "sessoes_historico", "sessao_status", "pesquisar_web",
  "subagents_listar", "subagents_matar", "agents_criar" }
local any_old = false
for _, n in ipairs(OLD_NAMES) do if tools.registry[n] then any_old = true end end
check(not any_old, "nenhum nome antigo em português está registrado")

-- Coleta descrições de parâmetros (inclusive dentro de items).
local function param_descriptions(schema, out, path)
  out = out or {}
  if type(schema) ~= "table" then return out end
  if type(schema.properties) == "table" then
    for pname, p in pairs(schema.properties) do
      if type(p) == "table" then
        if p.description then out[#out + 1] = { path .. "." .. pname, p.description } end
        param_descriptions(p, out, path .. "." .. pname)
        if type(p.items) == "table" then param_descriptions(p.items, out, path .. "." .. pname .. "[]") end
      end
    end
  end
  return out
end

local names = {}
for name in pairs(tools.registry) do names[#names + 1] = name end
table.sort(names)
check(#names == 26, "26 tools registradas (encontradas " .. #names .. ")")

for _, name in ipairs(names) do
  local t = tools.registry[name]
  local d = t.desc or ""
  check(d:find("Use", 1, true) ~= nil, name .. ": descrição diz quando usar ('Use')")
  check(d:find("Do not", 1, true) ~= nil or d:find("Never", 1, true) ~= nil,
    name .. ": descrição diz quando NÃO usar ('Do not' ou 'Never')")
  check(#d >= 120 and #d <= 1400, name .. ": tamanho da descrição entre 120 e 1400 caracteres (" .. #d .. ")")
  local pt = has_pt(d)
  check(pt == nil, name .. ": descrição sem português" .. (pt and (" (achei '" .. pt .. "')") or ""))
  for pname in pairs((t.schema or {}).properties or {}) do
    local bad = { nome = true, identidade = true, funcoes = true, confirmado = true, linhas = true }
    check(not bad[pname], name .. ": nome de parâmetro '" .. pname .. "' em inglês")
  end
  for _, pd in ipairs(param_descriptions(t.schema, nil, name)) do
    local ppt = has_pt(pd[2])
    check(ppt == nil, name .. " / " .. pd[1] .. ": parâmetro sem português" .. (ppt and (" (achei '" .. ppt .. "')") or ""))
  end
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
