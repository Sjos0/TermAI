-- tests/doc_gap_surfaces_spec/01_n_unit_tests_superf_cies_d.lua — parte de doc_gap_surfaces_spec.lua (ver fachada).
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

  local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a") or ""
    f:close()
    return s
  end


  print("\n=== Unit tests: superfícies DOC-GAP (#55 #56 #54 / PR #68) ===\n")

  -- ─────────────────────────────────────────────────────────────
  sec("commands.available — lista canônica (#55)")
  -- ─────────────────────────────────────────────────────────────

  local available = require("commands.available")

  T("M.commands é tabela não-vazia",
    type(available.commands) == "table" and #available.commands > 0)

  local by_name = {}
  local dup = false
  for _, cmd in ipairs(available.commands) do
    if type(cmd.name) ~= "string" or cmd.name == "" then
      T("cada entry tem name string", false, tostring(cmd.name))
    end
    if by_name[cmd.name] then dup = true end
    by_name[cmd.name] = cmd
  end
  T("nomes de slash únicos", not dup)

  local required = {
    "/models", "/config", "/commands", "/new", "/reset", "/session",
    "/clear", "/compact", "/status", "/restart", "/help", "/sair",
  }
  for _, name in ipairs(required) do
    T("lista inclui " .. name, by_name[name] ~= nil)
  end

  T("/compact tem descrição útil",
    by_name["/compact"] and type(by_name["/compact"].desc) == "string"
    and #by_name["/compact"].desc > 0)
  T("/status tem descrição útil",
    by_name["/status"] and type(by_name["/status"].desc) == "string"
    and #by_name["/status"].desc > 0)
  T("/help descreve slash (não ajuda CLI genérica)",
    by_name["/help"] and (by_name["/help"].desc:find("[Ss]lash") ~= nil
      or by_name["/help"].desc:find("[Aa]juda") ~= nil))

  -- ─────────────────────────────────────────────────────────────
  sec("commands.available.filter")
  -- ─────────────────────────────────────────────────────────────

  local all = available.filter(nil)
  T("filter(nil) devolve lista completa", #all == #available.commands)

  local all2 = available.filter("")
  T("filter vazio devolve lista completa", #all2 == #available.commands)

  local compact_hits = available.filter("/comp")
  local has_compact = false
  for _, c in ipairs(compact_hits) do
    if c.name == "/compact" then has_compact = true end
  end
  T("filter(/comp) encontra /compact", has_compact)

  local status_hits = available.filter("status")
  local has_status = false
  for _, c in ipairs(status_hits) do
    if c.name == "/status" then has_status = true end
  end
  T("filter(status) encontra /status", has_status)

  local none = available.filter("/zzz_inexistente_xyz")
  T("filter prefixo inexistente → vazio", #none == 0)

  -- ─────────────────────────────────────────────────────────────
  sec("/help TUI usa available — não help CLI (#56)")
  -- ─────────────────────────────────────────────────────────────

  local simple_src = read_file("agent/main_loop/commands_router/simple.lua")
    or read_file("./agent/main_loop/commands_router/simple.lua")

  if simple_src then
    T("simple.lua require commands.available",
      simple_src:find("commands.available", 1, true) ~= nil)
    T("simple.lua NÃO dofile help.lua no path /help",
      not simple_src:find("/commands/help.lua", 1, true))
    T("bloco /help itera available.commands",
      simple_src:find("available.commands", 1, true) ~= nil)
  else
    T("simple.lua legível no cwd", false, "rode da raiz do clone")
  end

  -- ─────────────────────────────────────────────────────────────
  sec("mapa CLI main.lua (#54)")
end

return M
