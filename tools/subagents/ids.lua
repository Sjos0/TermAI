-- tools/subagents/ids.lua — Geração de runId e childSessionKey.
local M = {}

local function hex_random(n)
  local f = io.open("/dev/urandom", "rb")
  if f then
    local b = f:read(n)
    f:close()
    if b and #b == n then
      local parts = {}
      for i = 1, n do
        parts[#parts + 1] = string.format("%02x", b:byte(i))
      end
      return table.concat(parts)
    end
  end
  math.randomseed(os.time() + math.floor(os.clock() * 1e6) % 1000)
  local chars = "0123456789abcdef"
  local r = ""
  for _ = 1, n * 2 do
    local i = math.random(1, 16)
    r = r .. chars:sub(i, i)
  end
  return r
end

function M.run_id()
  return hex_random(4)
end

function M.child_session_key(agent_id, run_id)
  return "agent:" .. tostring(agent_id) .. ":subagent:" .. tostring(run_id)
end

function M.transcript_path(agent_id, run_id)
  local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
  local dir = HOME .. "/.TermAI/subagents/transcripts"
  os.execute("mkdir -p '" .. dir .. "'")
  local key = M.child_session_key(agent_id, run_id)
  return dir .. "/" .. (key:gsub(":", "-")) .. ".jsonl"
end

return M
