-- diag/log.lua — Log estruturado (JSONL) com RAM do processo. Rotaciona em 1 MB (espaço limitado no celular).
local json  = require("json")
local paths = require("tools.agents.paths")
local M = {}

M.MAX_BYTES = 1024 * 1024

function M.dir()
  return paths.root() .. "/logs"
end

function M.path()
  return M.dir() .. "/termai.jsonl"
end

-- RSS em KB de um processo (padrão: este). Lê /proc, funciona no Linux e no Termux.
function M.rss_kb(pid)
  local f = io.open(pid and ("/proc/" .. pid .. "/status") or "/proc/self/status", "r")
  if not f then return nil end
  local kb
  for line in f:lines() do
    local v = line:match("^VmRSS:%s*(%d+)")
    if v then kb = tonumber(v); break end
  end
  f:close()
  return kb
end

local function own_pid()
  local f = io.open("/proc/self/stat", "r")
  if not f then return nil end
  local pid = f:read("*l"):match("^(%d+)")
  f:close()
  return tonumber(pid)
end

local function rotate_if_big(p)
  local f = io.open(p, "r")
  if not f then return end
  local size = f:seek("end") or 0
  f:close()
  if size > M.MAX_BYTES then os.rename(p, p .. ".1") end
end

-- Grava uma linha. fields é uma tabela simples (strings, números, booleanos).
function M.write(level, event, fields)
  os.execute(string.format("mkdir -p '%s'", M.dir()))
  local p = M.path()
  rotate_if_big(p)
  local rec = { t = os.time(), level = level, event = event, pid = own_pid(), rss_kb = M.rss_kb() }
  for k, v in pairs(fields or {}) do rec[k] = v end
  local f = io.open(p, "a")
  if not f then return false end
  f:write(json.encode(rec) .. "\n")
  f:close()
  return true
end

function M.info(event, fields)  return M.write("info", event, fields) end
function M.warn(event, fields)  return M.write("warn", event, fields) end
function M.error(event, fields) return M.write("error", event, fields) end

-- Últimas n linhas do log geral.
function M.tail(n)
  local lines = {}
  local f = io.open(M.path(), "r")
  if not f then return lines end
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  local out = {}
  for i = math.max(1, #lines - (n or 50) + 1), #lines do out[#out + 1] = lines[i] end
  return out
end

return M
