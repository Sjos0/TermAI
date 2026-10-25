-- tests/disabled_tools_spec/02_parte.lua — parte de disabled_tools_spec.lua (ver fachada).
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

  T("call sem 2º arg não explode na assinatura",
    (function()
      local r = tools.call("sem-pipe-aqui")
      return type(r) == "string" and r:find("Sintaxe") ~= nil
    end)())

  T("call_structured sem opts.disabled_tools aceita opts vazio",
    (function()
      local r = tools.call_structured("ToolInexistenteXYZ999", {}, {})
      return type(r) == "string" and r:find("não existe") ~= nil
    end)())

  -- ─────────────────────────────────────────────────────────────
  sec("payload / context / runner / xml contratos (leitura estática)")
end

return M
