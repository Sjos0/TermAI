-- tools/subagents/registry.lua — Estado persistente dos runs: uma pasta por run com run.json.
local json  = require("json")
local paths = require("tools.agents.paths")
local M = {}

function M.base()
  return paths.root() .. "/subagents"
end

function M.dir(run_id)
  return M.base() .. "/" .. run_id
end

function M.new_id()
  return string.format("sub-%x%04x", os.time(), math.random(0, 0xffff))
end

-- Grava run.json de forma atômica (tmp + rename): nunca fica JSON pela metade.
function M.save(rec)
  os.execute(string.format("mkdir -p '%s'", M.dir(rec.runId)))
  local path = M.dir(rec.runId) .. "/run.json"
  local f = io.open(path .. ".tmp", "w")
  if not f then return false end
  f:write(json.encode(rec))
  f:close()
  return os.rename(path .. ".tmp", path) ~= nil
end

function M.load(run_id)
  if type(run_id) ~= "string" or not run_id:match("^sub%-%x+$") then return nil end
  local f = io.open(M.dir(run_id) .. "/run.json", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ok, rec = pcall(json.decode, content)
  return (ok and type(rec) == "table") and rec or nil
end

-- Todos os runs, do mais antigo para o mais novo.
function M.list()
  local out = {}
  local h = io.popen("ls -1 '" .. M.base() .. "' 2>/dev/null")
  if not h then return out end
  for name in h:lines() do
    local rec = M.load(name)
    if rec then out[#out + 1] = rec end
  end
  h:close()
  table.sort(out, function(a, b) return (a.created_at or 0) < (b.created_at or 0) end)
  return out
end

function M.remove(run_id)
  os.execute(string.format("rm -rf '%s'", M.dir(run_id)))
end

function M.write_result(run_id, text)
  local f = io.open(M.dir(run_id) .. "/result.txt", "w")
  if not f then return false end
  f:write(text or "")
  f:close()
  return true
end

function M.read_result(run_id)
  local f = io.open(M.dir(run_id) .. "/result.txt", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

-- Snapshot parcial enquanto o filho roda (issue #93). Já sai redigido.
function M.write_partial(run_id, text)
  local f = io.open(M.dir(run_id) .. "/result.partial.txt", "w")
  if not f then return false end
  f:write(text or "")
  f:close()
  return true
end

-- Sem result.txt (morreu ou estourou o prazo), promove o parcial a resultado. Devolve true se promoveu.
function M.promote_partial(run_id)
  if M.read_result(run_id) ~= nil then return false end
  local f = io.open(M.dir(run_id) .. "/result.partial.txt", "r")
  if not f then return false end
  local text = f:read("*a") or ""
  f:close()
  if text == "" then return false end
  return M.write_result(run_id, text)
end

return M
