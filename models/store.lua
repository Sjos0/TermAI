local json = require("json")
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.PATH = HOME .. "/.TermAI/agents/main/agent/models.json"
M._data = nil

function M.load()
  local f = io.open(M.PATH, "r")
  if not f then
    M._data = { active = "", providers = {} }
    return M._data
  end
  local ok, data = pcall(json.decode, f:read("*a"))
  f:close()
  if not ok then
    M._data = { active = "", providers = {} }
    return M._data
  end
  M._data = data
  return M._data
end

function M.save()
  if not M._data then return false end
  local f = io.open(M.PATH, "w")
  if not f then return false end
  f:write(json.encode(M._data))
  f:close()
  return true
end

function M.data()
  if not M._data then M.load() end
  return M._data
end

return M
