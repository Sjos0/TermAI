-- tests/doc_gap_surfaces_spec.lua
-- Regressão PR #68 / Issues #55 #56 #54 (e inventário alinhado ao batch DOC-GAP).
--
-- "E se isso mudar?": se /compact ou /status sumirem de available.lua, se
-- /help da TUI voltar a dofile da ajuda CLI, ou se skills/npx/restart
-- sumirem do mapa CLI — este arquivo grita antes do usuário na TUI.
--
-- Escopo: contratos de superfície (lista canônica + wiring). Não cobre
-- ortografia do README nem inventário amostral de status.lua.

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
T("filter(\"\") devolve lista completa", #all2 == #available.commands)

local compact_hits = available.filter("/comp")
local has_compact = false
for _, c in ipairs(compact_hits) do
  if c.name == "/compact" then has_compact = true end
end
T("filter(\"/comp\") encontra /compact", has_compact)

local status_hits = available.filter("status")
local has_status = false
for _, c in ipairs(status_hits) do
  if c.name == "/status" then has_status = true end
end
T("filter(\"status\") encontra /status", has_status)

local none = available.filter("/zzz_inexistente_xyz")
T("filter prefixo inexistente → vazio", #none == 0)

-- ─────────────────────────────────────────────────────────────
sec("/help TUI usa available — não help CLI (#56)")
-- ─────────────────────────────────────────────────────────────

local simple_src = read_file("agent/main_loop/commands_router/simple.lua")
  or read_file("./agent/main_loop/commands_router/simple.lua")

if simple_src then
  T("simple.lua require commands.available",
    simple_src:find('require%(%s*["\']commands%.available["\']%s*%)') ~= nil)
  T("simple.lua NÃO dofile help.lua no path /help",
    -- ainda pode mencionar help em comentário; não deve carregar a ajuda CLI
    not simple_src:find("dofile%s*%(%s*BASE%s*%.%.%s*["\']/commands/help%.lua["\']"))
  T("bloco /help itera available.commands",
    simple_src:find("available%.commands") ~= nil)
else
  T("simple.lua legível no cwd", false, "rode da raiz do clone")
end

-- ─────────────────────────────────────────────────────────────
sec("mapa CLI main.lua (#54)")
-- ─────────────────────────────────────────────────────────────

local main_src = read_file("main.lua") or read_file("./main.lua")
if main_src then
  for _, key in ipairs({ "tui", "status", "models", "restart", "config", "update", "npx", "skills" }) do
    T("main.lua mapa tem chave " .. key,
      main_src:find(key .. "%s*=") ~= nil)
  end
  T("banner menciona TermAI skills",
    main_src:find("TermAI skills") ~= nil)
  T("banner menciona TermAI npx",
    main_src:find("TermAI npx") ~= nil)
  T("banner menciona TermAI restart",
    main_src:find("TermAI restart") ~= nil)
else
  T("main.lua legível no cwd", false, "rode da raiz do clone")
end

-- ─────────────────────────────────────────────────────────────
sec("help.lua CLI lista subcomandos reais (#65 #54)")
-- ─────────────────────────────────────────────────────────────

local help_src = read_file("commands/help.lua") or read_file("./commands/help.lua")
if help_src then
  for _, word in ipairs({ "config", "skills", "npx", "restart", "update", "tui", "status", "models" }) do
    T("help.lua menciona " .. word, help_src:find(word) ~= nil)
  end
else
  T("help.lua legível no cwd", false, "rode da raiz do clone")
end

-- ─────────────────────────────────────────────────────────────
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Contratos de superfície DOC-GAP (#55 #56 #54) ok")
end
