-- commands/cron/jobs.lua — ações do cron: lista os jobs, executa e mostra o histórico.
local N = require("commands.cron.nucleo")
local JOBS, BIN_DIR, STATE_DIR = N.JOBS, N.BIN_DIR, N.STATE_DIR
local shell_quote, read_crontab, parse_summary = N.shell_quote, N.read_crontab, N.parse_summary

local function list_jobs()
  local content, err = read_crontab()
  if not content then
    io.stderr:write((err or "Não foi possível ler o crontab.") .. "\n")
    os.exit(1)
  end
  local timezone = "timezone do sistema"
  local found = {}
  for line in content:gmatch("[^\r\n]+") do
    local tz = line:match("^%s*CRON_TZ%s*=%s*(.-)%s*$")
    if tz then timezone = tz end
    for id, job in pairs(JOBS) do
      if line:find(job.script, 1, true) and not line:match("^%s*#") then
        local schedule = line:match("^%s*(%S+%s+%S+%s+%S+%s+%S+%s+%S+)") or line
        found[#found + 1] = { id = id, title = job.title, schedule = schedule }
      end
    end
  end
  table.sort(found, function(a, b) return a.id < b.id end)
  io.write("TermAI Cron - backend: cron do sistema\n")
  io.write("Fuso horário: " .. timezone .. "\n")
  if #found == 0 then
    io.write("Nenhum job TermAI encontrado no crontab.\n")
    return
  end
  for _, job in ipairs(found) do
    io.write(string.format("- %s (%s): %s\n", job.id, job.title, job.schedule))
  end
end

local function run_job(id)
  local job = JOBS[id]
  if not job then
    io.stderr:write("Job desconhecido. Use: bugs-hunter ou code-review.\n")
    os.exit(2)
  end
  local path = BIN_DIR .. "/" .. job.script
  local f = io.open(path, "r")
  if not f then
    io.stderr:write("Runner não encontrado: " .. path .. "\n")
    os.exit(2)
  end
  f:close()
  io.write("Executando " .. job.title .. " pelo runner agendado...\n")
  local ok, kind, code = os.execute(shell_quote(path))
  if ok == true or code == 0 then
    io.write("Job concluído com sucesso.\n")
    return
  end
  local exit_code = tonumber(code) or 1
  io.stderr:write("Job falhou: tipo=" .. tostring(kind) .. " código=" .. tostring(exit_code) .. "\n")
  os.exit(exit_code > 0 and exit_code or 1)
end

--- Lista nomes de pastas de run sob root (só nomes, sem path).
-- Portátil: `ls -1` (sem -t/-printf). Ordenação pelo nome do stamp
-- (%Y%m%dT%H%M%S%z do runner) — lexicográfico reverso = mais recente primeiro.
-- Issue #143: evita find -printf (GNU) e também -t se o ambiente for mínimo.
local function collect_run_names(root)
  local names = {}
  local cmd = "ls -1 " .. shell_quote(root) .. " 2>/dev/null"
  local pipe = io.popen(cmd)
  if not pipe then return names end
  for line in pipe:lines() do
    local name = line:match("^%s*(.-)%s*$")
    if name and name ~= "" and name ~= "." and name ~= ".." then
      -- Só aceita entradas que parecem diretório de run (stamp) ou qualquer
      -- nome não vazio; validação fina é existência de summary.md depois.
      names[#names + 1] = name
    end
  end
  pipe:close()
  table.sort(names, function(a, b) return a > b end)
  return names
end

local function list_runs(id, limit)
  if not JOBS[id] then
    io.stderr:write("Job desconhecido. Use: bugs-hunter ou code-review.\n")
    os.exit(2)
  end
  limit = tonumber(limit) or 10
  limit = math.max(1, math.min(50, math.floor(limit)))
  local root = STATE_DIR .. "/" .. id

  local names = collect_run_names(root)
  local dirs = {}
  for _, name in ipairs(names) do
    if #dirs >= limit then break end
    local path = root .. "/" .. name
    -- Confirma que é diretório: summary.md ou path abre como dir via listagem.
    local summary = path .. "/summary.md"
    local f = io.open(summary, "r")
    if f then
      f:close()
      dirs[#dirs + 1] = path
    else
      -- Pasta sem summary ainda conta no histórico (run em andamento / incompleto)
      local probe = io.popen("test -d " .. shell_quote(path) .. " && echo y")
      local ok = probe and probe:read("*l")
      if probe then probe:close() end
      if ok == "y" then
        dirs[#dirs + 1] = path
      end
    end
  end

  io.write("Histórico - " .. JOBS[id].title .. " (mais recentes primeiro)\n")
  if #dirs == 0 then
    io.write("Nenhuma execução registrada.\n")
    return
  end
  for _, path in ipairs(dirs) do
    local s = parse_summary(path)
    if s then
      io.write(string.format("- %s | exit=%s | início=%s | modelo=%s | fallback=%s\n",
        path:match("([^/]+)$") or path,
        s.exit_code or "desconhecido",
        s.started or "desconhecido",
        s.model_primary or "desconhecido",
        s.model_fallback or "desconhecido"))
    else
      io.write("- " .. (path:match("([^/]+)$") or path) .. " | resumo ainda não disponível\n")
    end
  end
end

return {
  list_jobs = list_jobs,
  run_job = run_job,
  list_runs = list_runs,
  -- exportado para spec (issue #143)
  _collect_run_names = collect_run_names,
}
