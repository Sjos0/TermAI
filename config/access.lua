local store = require("config.store")
local M = {}

function M.get(path)
  local current = store.data()
  for part in path:gmatch("[^%.]+") do
    if type(current) ~= "table" then return nil end
    current = current[part]
  end
  return current
end

function M.set(path, value)
  local d = store.data()
  local parts = {}
  for part in path:gmatch("[^%.]+") do parts[#parts+1] = part end
  local current = d
  for i = 1, #parts - 1 do
    if type(current[parts[i]]) ~= "table" then current[parts[i]] = {} end
    current = current[parts[i]]
  end
  current[parts[#parts]] = value
  return store.save()
end

function M.get_agent(id)
  for _, agent in ipairs(store.data().agents and store.data().agents.list or {}) do
    if agent.id == id then return agent end
  end
  return nil
end

return M
