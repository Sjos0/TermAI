local store  = require("models.store")
local resolve = require("models.resolve")
local list   = require("models.list")
local crud   = require("models.crud")
local M = {}

M.load            = store.load
M.save            = store.save
M.resolve         = resolve.resolve
M.list            = list.list
M.list_providers  = list.list_providers
M.get_active      = crud.get_active
M.set_active      = crud.set_active
M.add_model       = crud.add_model
M.remove_model    = crud.remove_model
M.add_provider    = crud.add_provider
M.remove_provider = crud.remove_provider
M.update_api_key  = crud.update_api_key

return M
