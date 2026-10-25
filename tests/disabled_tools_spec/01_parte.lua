-- tests/disabled_tools_spec/01_parte.lua — parte de disabled_tools_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()


  local function T(name, ok, detail)
    if ok then
      harness.pass = harness.pass + 1
      print("  OK  " .. name)
    else
      harness.fail = harness.fail + 1
      print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
    end
  end

  local function sec(title)
    print("\n=== " .. title .. " ===")
  end

  local tools = require("tools")

  -- Nomes reais do registry (ordem não garantida em pairs)

  local all_names = {}
  for name in pairs(tools.registry) do
    all_names[#all_names + 1] = name
  end
  table.sort(all_names)
  local sample = all_names[1]

  local sample2 = all_names[2] or all_names[1]


  -- ─────────────────────────────────────────────────────────────

  local full = tools.get_schema()

  local function schema_names(schema)
    local n = {}
    if not schema then return n end
    for _, entry in ipairs(schema) do
      local fn = entry["function"]
      if fn and fn.name then n[#n + 1] = fn.name end
    end
    return n
  end

  local full_names = schema_names(full)

  print("\n=== Unit tests: disabled tools per agent (Issue #32 / PR #46) ===\n")

  local all_names = {}
  for name in pairs(tools.registry) do
    all_names[#all_names + 1] = name
  end
  table.sort(all_names)
  T("registry tem tools registradas", #all_names > 0, "count=" .. tostring(#all_names))

  sec("get_schema sem filtro (regressão zero)")
  -- ─────────────────────────────────────────────────────────────

  T("get_schema() retorna tabela", type(full) == "table")
  T("get_schema() não-vazio sem filtro", full ~= nil and #full > 0)


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

end

return M
