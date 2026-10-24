local store = require("config.store")
local access = require("config.access")
local M = {}

M.load      = store.load
M.save      = store.save
M.get       = access.get
M.set       = access.set
M.get_agent = access.get_agent

return M
