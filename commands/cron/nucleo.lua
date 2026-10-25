-- commands/cron/nucleo.lua — constantes, tabela de jobs e leitura do crontab/resumos.
-- Usado por commands/cron.lua (fachada) e commands/cron/jobs.lua.
local HOME_DIR = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BIN_DIR = os.getenv("TERMAI_CRON_BIN_DIR") or (HOME_DIR .. "/.local/bin")
local STATE_DIR = os.getenv("TERMAI_CRON_STATE_DIR") or (HOME_DIR .. "/.local/state/termai/jobs")
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

local function parse_summary(path)
  local content = read_text(path .. "/summary.md")
  if not content then return nil end
  local result = {}
  for key, value in content:gmatch("([%w_]+)=([^\r\n]+)") do
    result[key] = value
  end
  return result
end

return {
  HOME_DIR = HOME_DIR, BIN_DIR = BIN_DIR, STATE_DIR = STATE_DIR, CRONTAB_FILE = CRONTAB_FILE,
  JOBS = JOBS, shell_quote = shell_quote, read_crontab = read_crontab, parse_summary = parse_summary,
}
