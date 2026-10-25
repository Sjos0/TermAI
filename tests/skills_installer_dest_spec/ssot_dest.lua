-- SSOT de destino: get_global_skills_dir, get_skills_dir (main e agentes nomeados) e oracle de get_dest.
local harness = require("tests.helpers.harness")
local ctx = require("tests.skills_installer_dest_spec.contexto")
local T, sec = harness.T_so_falhas, harness.sec
local skills_utils, inst_utils = ctx.skills_utils, ctx.inst_utils
local PROJECT_ROOT, GLOBAL, MAIN_WS = ctx.PROJECT_ROOT, ctx.GLOBAL, ctx.MAIN_WS
local read_file = ctx.read_file

local M = {}

function M.run()
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
end

return M
