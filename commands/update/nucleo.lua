-- commands/update/nucleo.lua — constantes, cores e helpers do update (usado pela fachada e pelos passos).
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"
-- Path quotado para git -C (protege espaços e metacaracteres no HOME)
local BASE_Q = "'" .. BASE:gsub("'", "'\\''") .. "'"
local release = require("tools.update.release")

local c = {
  reset = "\27[0m",
  bold  = "\27[1m",
  dim   = "\27[2m",
  green = "\27[38;5;114m",
  red   = "\27[31m",
  cyan  = "\27[38;5;80m",
  gray  = "\27[38;5;245m",
  yellow= "\27[38;5;220m",
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function run(cmd)
  local h = io.popen(cmd .. " 2>&1")
  if not h then return nil, "falha ao executar: " .. cmd end
  local out = h:read("*a") or ""
  local ok, _, code = h:close()
  -- Lua 5.4: close() returns true/false, exit type, exit code
  local exit = (type(code) == "number") and code or (ok and 0 or 1)
  return out:gsub("%s+$", ""), exit
end

local function git(args) return run("git -C " .. BASE_Q .. " " .. args) end

local function short_sha(sha)
  if not sha or sha == "" then return "?" end
  return sha:sub(1, 7)
end

local function read_version()
  local f = io.open(BASE .. "/VERSION", "r")
  if not f then return "?" end
  local v = (f:read("*a") or ""):match("^%s*(.-)%s*$") or "?"
  f:close()
  return v
end

local function step_ok(msg)
  io.write("  " .. c.green .. "✓" .. c.reset .. "  " .. msg .. "\n")
end

local function step_fail(msg)
  io.write("  " .. c.red .. "✗" .. c.reset .. "  " .. msg .. "\n")
end

local function step_warn(msg)
  io.write("  " .. c.yellow .. "!" .. c.reset .. "  " .. msg .. "\n")
end

return {
  HOME = HOME, BASE = BASE, BASE_Q = BASE_Q, release = release, c = c,
  run = run, git = git, short_sha = short_sha, read_version = read_version,
  step_ok = step_ok, step_fail = step_fail, step_warn = step_warn,
}
