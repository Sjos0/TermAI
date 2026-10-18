-- tools/subagents/store.lua — Índice persistente de child runs (~/.TermAI/subagents/runs.json).
local json = require("json")
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.DIR  = HOME .. "/.TermAI/subagents"
M.PATH = M.DIR .. "/runs.json"

local function ensure_dir()
  os.execute("mkdir -p '" .. M.DIR .. "'")
end

function M.load()
  ensure_dir()
  local f = io.open(M.PATH, "r")
  if not f then return { runs = {} } end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(json.decode, content)
  if not ok or type(data) ~= "table" then return { runs = {} } end
  if type(data.runs) ~= "table" then data.runs = {} end
  return data
end

function M.save(data)
  ensure_dir()
  local f = io.open(M.PATH, "w")
  if not f then return false end
  f:write(json.encode(data or { runs = {} }))
  f:close()
  return true
end

function M.get(run_id)
  local data = M.load()
  for _, r in ipairs(data.runs) do
    if r.runId == run_id then return r, data end
  end
  return nil, data
end

function M.upsert(run)
  local data = M.load()
  for i, r in ipairs(data.runs) do
    if r.runId == run.runId then
      data.runs[i] = run
      M.save(data)
      return run
    end
  end
  data.runs[#data.runs + 1] = run
  M.save(data)
  return run
end

function M.list(filter)
  local data = M.load()
  local out = {}
  for _, r in ipairs(data.runs) do
    local ok = true
    if filter then
      if filter.status and r.status ~= filter.status then ok = false end
      if filter.parent_agent_id and r.parent_agent_id ~= filter.parent_agent_id then ok = false end
      if filter.agentId and r.agentId ~= filter.agentId then ok = false end
    end
    if ok then out[#out + 1] = r end
  end
  return out
end

function M.count_active(parent_agent_id)
  local n = 0
  for _, r in ipairs(M.list()) do
    if (r.status == "queued" or r.status == "running") then
      if not parent_agent_id or r.parent_agent_id == parent_agent_id then
        n = n + 1
      end
    end
  end
  return n
end

return M
