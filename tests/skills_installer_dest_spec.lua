-- tests/skills_installer_dest_spec.lua
-- Regressão Issue #72 / PR #75: destino do CLI installer = SSOT do runtime.
--
-- "E se isso mudar?": se get_dest voltar a gravar em ~/.TermAI/agents/,
-- se github_installer forçar global, ou se defaults de install_from_*
-- hardcodarem HOME/.TermAI/skills fora do SSOT — este arquivo grita.
--
-- Tipos: unitário (paths puros), oracle (installer.utils ≡ skills.utils),
-- invariante (nunca /agents/), contrato estático (leitura de fontes),
-- bordas (nil, main, agent nomeado, flags vazios).

package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0

local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    -- silencioso no verde em massa; só imprime falhas + seções
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

print("\n=== Unit tests: skills installer dest SSOT (Issue #72 / PR #75) ===\n")

local helpers = require("tools.helpers")
local skills_utils = require("tools.skills.utils")
local inst_utils = require("tools.skills.skills_installer.utils")

local PROJECT_ROOT = helpers.PROJECT_ROOT
local GLOBAL = PROJECT_ROOT .. "/skills"
local MAIN_WS = PROJECT_ROOT .. "/workspace/skills"

-- ─────────────────────────────────────────────────────────────
sec("SSOT tools.skills.utils — get_global_skills_dir")
-- ─────────────────────────────────────────────────────────────

T("get_global_skills_dir retorna string", type(skills_utils.get_global_skills_dir()) == "string")
T("get_global_skills_dir == PROJECT_ROOT/skills",
  skills_utils.get_global_skills_dir() == GLOBAL,
  skills_utils.get_global_skills_dir())
T("global termina com /skills",
  skills_utils.get_global_skills_dir():match("/skills$") ~= nil)
T("global NÃO contém /agents/",
  not skills_utils.get_global_skills_dir():find("/agents/", 1, true))
T("global NÃO contém /workspace/",
  not skills_utils.get_global_skills_dir():find("/workspace/", 1, true))
T("global é sob PROJECT_ROOT",
  skills_utils.get_global_skills_dir():sub(1, #PROJECT_ROOT) == PROJECT_ROOT)
T("get_global_skills_dir determinístico",
  skills_utils.get_global_skills_dir() == skills_utils.get_global_skills_dir())

-- ─────────────────────────────────────────────────────────────
sec("SSOT tools.skills.utils — get_skills_dir (main / nil)")
-- ─────────────────────────────────────────────────────────────

T("get_skills_dir(nil) == workspace/skills",
  skills_utils.get_skills_dir(nil) == MAIN_WS)
T("get_skills_dir(\"main\") == workspace/skills",
  skills_utils.get_skills_dir("main") == MAIN_WS)
T("get_skills_dir(\"\") trata como non-main se truthy vazio?",
  -- string vazia é truthy em Lua no `if agent_name and agent_name ~= \"main\"`
  -- \"\" ~= \"main\" → entra no branch workspace/<name>/skills
  skills_utils.get_skills_dir("") == PROJECT_ROOT .. "/workspace//skills"
  or skills_utils.get_skills_dir("") == MAIN_WS)
T("main path termina com /workspace/skills",
  skills_utils.get_skills_dir("main"):match("/workspace/skills$") ~= nil)
T("main path NÃO contém /agents/",
  not skills_utils.get_skills_dir("main"):find("/agents/", 1, true))
T("nil path NÃO contém /agents/",
  not skills_utils.get_skills_dir(nil):find("/agents/", 1, true))

-- ─────────────────────────────────────────────────────────────
sec("SSOT get_skills_dir — agentes nomeados (tabela)")
-- ─────────────────────────────────────────────────────────────

local agents = {
  "foo", "bar", "research", "coder", "reviewer", "test", "agent1",
  "my-agent", "agent_2", "A", "z", "longname0123456789",
  "dev", "ops", "qa", "bot", "assistant", "worker", "planner",
  "writer", "reader", "executor",
}

for _, name in ipairs(agents) do
  local path = skills_utils.get_skills_dir(name)
  local expected = PROJECT_ROOT .. "/workspace/" .. name .. "/skills"
  T("get_skills_dir(" .. name .. ") path canônico", path == expected, path)
  T("get_skills_dir(" .. name .. ") sem /agents/", not path:find("/agents/", 1, true))
  T("get_skills_dir(" .. name .. ") sob workspace",
    path:find("/workspace/" .. name .. "/skills", 1, true) ~= nil)
end

-- ─────────────────────────────────────────────────────────────
sec("installer utils.get_dest — oracle vs SSOT")
-- ─────────────────────────────────────────────────────────────

T("get_dest(nil) == get_global_skills_dir",
  inst_utils.get_dest(nil) == skills_utils.get_global_skills_dir())
T("get_dest({}) == get_global_skills_dir",
  inst_utils.get_dest({}) == skills_utils.get_global_skills_dir())
T("get_dest({global=true}) sem agent → global",
  inst_utils.get_dest({ global = true }) == skills_utils.get_global_skills_dir())
T("get_dest({agent=nil}) → global",
  inst_utils.get_dest({ agent = nil }) == skills_utils.get_global_skills_dir())
T("get_dest({agent=\"main\"}) == get_skills_dir(main)",
  inst_utils.get_dest({ agent = "main" }) == skills_utils.get_skills_dir("main"))

for _, name in ipairs(agents) do
  local a = inst_utils.get_dest({ agent = name })
  local b = skills_utils.get_skills_dir(name)
  T("oracle get_dest(agent=" .. name .. ") ≡ get_skills_dir", a == b, a)
end

-- ─────────────────────────────────────────────────────────────
sec("invariante: nunca grava em /.TermAI/agents/")
-- ─────────────────────────────────────────────────────────────

local dest_samples = {
  inst_utils.get_dest(nil),
  inst_utils.get_dest({}),
  inst_utils.get_dest({ agent = "main" }),
  inst_utils.get_dest({ agent = "foo" }),
  inst_utils.get_dest({ agent = "bar", global = true }), -- agent prevalece
  skills_utils.get_global_skills_dir(),
  skills_utils.get_skills_dir("main"),
  skills_utils.get_skills_dir("x"),
}

for i, p in ipairs(dest_samples) do
  T("sample[" .. i .. "] sem /.TermAI/agents/",
    not p:find("/.TermAI/agents/", 1, true) and not p:find("/agents/", 1, true),
    p)
end

-- agent prevalece sobre global flag
T("agent=foo + global=true ainda é workspace/foo",
  inst_utils.get_dest({ agent = "foo", global = true })
    == skills_utils.get_skills_dir("foo"))

-- ─────────────────────────────────────────────────────────────
sec("contratos estáticos — fontes do PR")
-- ─────────────────────────────────────────────────────────────

local u_src = read_file("tools/skills/skills_installer/utils.lua")
  or read_file("./tools/skills/skills_installer/utils.lua")
local i_src = read_file("tools/skills/skills_installer/installer.lua")
  or read_file("./tools/skills/skills_installer/installer.lua")
local g_src = read_file("tools/skills/skills_installer/github_installer.lua")
  or read_file("./tools/skills/skills_installer/github_installer.lua")
local s_src = read_file("tools/skills/utils.lua")
  or read_file("./tools/skills/utils.lua")

if u_src then
  T("installer utils require tools.skills.utils",
    u_src:find("tools.skills.utils", 1, true) ~= nil)
  T("installer utils NÃO concatena /.TermAI/agents/",
    not u_src:find("/.TermAI/agents/", 1, true))
  T("installer utils chama get_skills_dir",
    u_src:find("get_skills_dir", 1, true) ~= nil)
  T("installer utils chama get_global_skills_dir",
    u_src:find("get_global_skills_dir", 1, true) ~= nil)
  T("installer utils tem function get_dest",
    u_src:find("function M.get_dest", 1, true) ~= nil)
else
  T("skills_installer/utils.lua legível", false)
end

if i_src then
  T("installer.lua require tools.skills.utils",
    i_src:find("tools.skills.utils", 1, true) ~= nil)
  T("installer.lua default tarball usa get_global_skills_dir",
    i_src:find("get_global_skills_dir", 1, true) ~= nil)
  T("installer.lua NÃO hardcode HOME/.TermAI/skills",
    not i_src:find('HOME .. "/.TermAI/skills"', 1, true)
    and not i_src:find("HOME..\"/.TermAI/skills\"", 1, true))
  T("installer.lua NÃO referencia /.TermAI/agents/",
    not i_src:find("/.TermAI/agents/", 1, true))
else
  T("installer.lua legível", false)
end

if g_src then
  T("github_installer NÃO require skills_installer.utils",
    -- não deve recalcular dest localmente
    not g_src:find("skills_installer.utils", 1, true))
  T("github_installer NÃO chama get_dest( (só comentário ok)",
    not g_src:find("get_dest(", 1, true))
  T("github_installer passa dest a install_from_files",
    g_src:find("install_from_files", 1, true) ~= nil
    and g_src:find(", dest%)") ~= nil or g_src:find(", dest") ~= nil)
  T("github_installer NÃO força agent=nil global",
    not g_src:find("agent = nil", 1, true))
  T("github_installer NÃO referencia /.TermAI/agents/",
    not g_src:find("/.TermAI/agents/", 1, true))
else
  T("github_installer.lua legível", false)
end

if s_src then
  T("skills.utils define get_skills_dir",
    s_src:find("function M.get_skills_dir", 1, true) ~= nil)
  T("skills.utils define get_global_skills_dir",
    s_src:find("function M.get_global_skills_dir", 1, true) ~= nil)
  T("skills.utils main usa workspace/skills flat",
    s_src:find("/workspace/skills", 1, true) ~= nil)
  T("skills.utils non-main usa workspace/<agent>/skills",
    s_src:find("/workspace/", 1, true) ~= nil)
else
  T("tools/skills/utils.lua legível", false)
end

-- ─────────────────────────────────────────────────────────────
sec("cli wiring — get_dest ainda usado no entry")
-- ─────────────────────────────────────────────────────────────

local cli_src = read_file("tools/skills/skills_installer/cli.lua")
  or read_file("./tools/skills/skills_installer/cli.lua")
if cli_src then
  T("cli.lua chama utils.get_dest",
    cli_src:find("get_dest", 1, true) ~= nil)
  T("cli.lua NÃO grava path agents hardcoded no destino",
    -- pode mencionar agents em texto; path de destino legado não deve ser montado
    not cli_src:find('"/.TermAI/agents/"', 1, true)
    and not cli_src:find("/.TermAI/agents/", 1, true))
else
  T("cli.lua legível", false, "opcional se path divergir")
end

-- ─────────────────────────────────────────────────────────────
sec("propriedades / invariantes extras")
-- ─────────────────────────────────────────────────────────────

-- Idempotência de resolução
for _, name in ipairs({ "main", "foo", "bar" }) do
  local p1 = inst_utils.get_dest({ agent = name })
  local p2 = inst_utils.get_dest({ agent = name })
  T("idempotente get_dest(" .. name .. ")", p1 == p2)
end

-- Todo path de agente nomeado contém o nome do agente
for _, name in ipairs({ "alpha", "beta", "gamma" }) do
  local p = inst_utils.get_dest({ agent = name })
  T("path contém nome do agente " .. name, p:find(name, 1, true) ~= nil)
end

-- Global nunca contém nome de agente fictício
T("global não contém 'foo'", not GLOBAL:find("foo", 1, true))
T("global == get_dest sem agent", GLOBAL == inst_utils.get_dest({}))

-- get_home existe e é string (API estável do SSOT)
T("get_home retorna string", type(skills_utils.get_home()) == "string")
T("get_home não vazio", #skills_utils.get_home() > 0)

-- file_exists API (borda sem I/O de skill real)
T("file_exists path inexistente → false",
  skills_utils.file_exists("/tmp/termai_skill_path_that_should_not_exist_xyz_72") == false)

-- ─────────────────────────────────────────────────────────────
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Regressão #72 / dest SSOT: todos os asserts passaram")
end
