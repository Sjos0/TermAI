-- Wiring do CLI (get_dest ainda usado no entry) e propriedades/invariantes extras.
local harness = require("tests.helpers.harness")
local ctx = require("tests.skills_installer_dest_spec.contexto")
local portable_tmp = require("tests.helpers.tmp")
local T, sec = harness.T_so_falhas, harness.sec
local skills_utils, inst_utils = ctx.skills_utils, ctx.inst_utils
local PROJECT_ROOT, GLOBAL, MAIN_WS = ctx.PROJECT_ROOT, ctx.GLOBAL, ctx.MAIN_WS
local read_file = ctx.read_file

local M = {}

function M.run()
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
    skills_utils.file_exists(portable_tmp.dir() .. "/termai_skill_path_that_should_not_exist_xyz_72") == false)
end

return M
