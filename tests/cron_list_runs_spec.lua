-- tests/cron_list_runs_spec.lua — issue #143: listagem portátil sem find -printf.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local TMPDIR = os.getenv("TMPDIR") or "/tmp"
local root = string.format("%s/termai_cron_runs_%d", TMPDIR, os.time())
assert(os.execute("mkdir -p " .. root .. "/old " .. root .. "/mid " .. root .. "/new") == true
  or os.execute("mkdir -p " .. root .. "/old " .. root .. "/mid " .. root .. "/new") == 0)

-- Stamps no formato do runner (lexicográfico reverso = mais recente primeiro)
local stamps = {
  "20261020T100000-0300",
  "20261026T120000-0300",
  "20261025T080000-0300",
}
for _, s in ipairs(stamps) do
  os.execute("mkdir -p " .. root .. "/" .. s)
  local f = io.open(root .. "/" .. s .. "/summary.md", "w")
  f:write("exit_code=0\nstarted=x\nmodel_primary=m\nmodel_fallback=f\n")
  f:close()
end

-- Isola STATE via env antes do require
os.execute("mkdir -p " .. root)
package.loaded["commands.cron.nucleo"] = nil
package.loaded["commands.cron.jobs"] = nil

-- Injeta nucleo mínimo se necessário — jobs usa STATE_DIR do nucleo real.
-- Testamos só _collect_run_names com shell_quote local.
local jobs = require("commands.cron.jobs")
assert(type(jobs._collect_run_names) == "function", "_collect_run_names deve ser exportado")

local names = jobs._collect_run_names(root)
assert(#names >= 3, "deveria listar pelo menos os 3 stamps, got " .. #names)

-- Mais recente primeiro
local idx = {}
for i, n in ipairs(names) do idx[n] = i end
assert(idx["20261026T120000-0300"] < idx["20261025T080000-0300"],
  "20261026 deveria vir antes de 20261025")
assert(idx["20261025T080000-0300"] < idx["20261020T100000-0300"],
  "20261025 deveria vir antes de 20261020")

-- Garantia: sem invocação de find nem flag -printf no comando de listagem
local src = io.open("commands/cron/jobs.lua", "r"):read("*a")
-- remove comentarios de linha para não falsar no texto documental
local code = src:gsub("%-%-[^
]*", "")
assert(not code:find("find%s"), "jobs.lua nao deve invocar find (issue #143)")
assert(not code:find("%-printf"), "jobs.lua nao deve usar -printf (issue #143)")
assert(code:find("ls %-1"), "jobs.lua deve listar com ls -1 portatil")

os.execute("rm -rf " .. root)
print("PASS  cron_list_runs_spec: ordenação por stamp + sem find -printf")
