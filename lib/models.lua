local store   = require("models.store")
local resolve = require("models.resolve")
local list    = require("models.list")
local crud    = require("models.crud")
local keys    = require("models.keys")
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
M.update_model    = crud.update_model
M.list_api_keys   = keys.list
M.active_api_key  = keys.active
M.add_api_key     = keys.add
M.remove_api_key  = keys.remove
M.set_active_api_key = keys.set_active
M.preview_api_key_rotation = keys.preview_rotation
M.commit_api_key_rotation = keys.commit_rotation
M.record_api_key  = keys.record
M.replace_api_keys = keys.replace

return M
