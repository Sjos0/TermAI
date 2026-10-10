-- TermAI cron: inspect and manually execute OS-cron jobs without a resident scheduler.
local BIN_DIR = os.getenv("TERMAI_CRON_BIN_DIR") or "/home/ubuntu/.local/bin"
local STATE_DIR = os.getenv("TERMAI_CRON_STATE_DIR") or "/home/ubuntu/.local/state/termai/jobs"
local CRONTAB_FILE = os.getenv("TERMAI_CRONTAB_FILE")

local JOBS = {
  ["bugs-hunter"] = { title = "Bugs Hunter", script = "termai-bugs-hunter-nightly.sh" },
  ["code-review"] = { title = "Code Review", script = "termai-code-review-nightly.sh" },
}

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function read_text(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function read_crontab()
  if CRONTAB_FILE and CRONTAB_FILE ~= "" then
    return read_text(CRONTAB_FILE) or ""
  end
  local pipe = io.popen("crontab -l 2>/dev/null")
  if not pipe then return nil, "Não foi possível executar crontab -l." end
  local content = pipe:read("*a")
  local ok, _, code = pipe:close()
  if not ok and code ~= 0 then return nil, "crontab -l falhou ou não há crontab instalado." end
  return content
end

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

local function parse_summary(path)
  local content = read_text(path .. "/summary.md")
  if not content then return nil end
  local result = {}
  for key, value in content:gmatch("([%w_]+)=([^\r\n]+)") do
    result[key] = value
  end
  return result
end

local function list_runs(id, limit)
  if not JOBS[id] then
    io.stderr:write("Job desconhecido. Use: bugs-hunter ou code-review.\n")
    os.exit(2)
  end
  limit = tonumber(limit) or 10
  limit = math.max(1, math.min(50, math.floor(limit)))
  local root = STATE_DIR .. "/" .. id
  local cmd = "find " .. shell_quote(root) .. " -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\\n' 2>/dev/null | sort -nr | head -n " .. limit
  local pipe = io.popen(cmd)
  if not pipe then
    io.stderr:write("Não foi possível consultar o histórico.\n")
    os.exit(1)
  end
  local dirs = {}
  for line in pipe:lines() do
    local path = line:match("^%S+%s+(.+)$")
    if path then dirs[#dirs + 1] = path end
  end
  pipe:close()
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

local action = arg[2]
if action == "--help" or action == "-h" or action == nil then
  io.write("Uso: TermAI cron list | run <bugs-hunter|code-review> | runs <job> [limite]\n")
  io.write("  list                Lista os jobs TermAI presentes no crontab do sistema\n")
  io.write("  run <job>           Executa agora o mesmo runner usado pelo cron\n")
  io.write("  runs <job> [limite] Lista as últimas execuções e seus códigos de saída\n")
elseif action == "list" then
  list_jobs()
elseif action == "run" then
  run_job(arg[3])
elseif action == "runs" then
  list_runs(arg[3], arg[4])
else
  io.stderr:write("Subcomando desconhecido: " .. tostring(action) .. "\n")
  io.stderr:write("Use: TermAI cron --help\n")
  os.exit(2)
end
