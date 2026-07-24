local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI/providers"

local _registry = nil

function M.load_all()
  if _registry then return _registry end
  _registry = {}

  local h = io.popen("ls " .. BASE .. "/*.lua 2>/dev/null")
  if not h then return _registry end
  for path in h:lines() do
    local name = path:match("([^/]+)%.lua$")
    if name and name ~= "init" then
      local ok, data = pcall(require, "providers." .. name)
      if ok and data and data.id then
        _registry[data.id] = data
      end
    end
  end
  h:close()
  return _registry
end

function M.list()
  local reg = M.load_all()
  local result = {}
  for _, prov in pairs(reg) do
    result[#result + 1] = prov
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

function M.get(id)
  return M.load_all()[id]
end

return M
