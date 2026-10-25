-- Invariante de nunca gravar em /agents/ e contratos estáticos lidos dos fontes do PR.
local harness = require("tests.helpers.harness")
local ctx = require("tests.skills_installer_dest_spec.contexto")
local T, sec = harness.T_so_falhas, harness.sec
local skills_utils, inst_utils = ctx.skills_utils, ctx.inst_utils
local PROJECT_ROOT, GLOBAL, MAIN_WS = ctx.PROJECT_ROOT, ctx.GLOBAL, ctx.MAIN_WS
local read_file = ctx.read_file

local M = {}

function M.run()
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
end

return M
