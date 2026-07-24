-- flush_index.lua — Gerencia o índice de flush para o memory flush.
local state       = require("session.manager.state")
local session_ops = require("session.manager.session_ops")
local store       = require("session.store")
local M = {}

local function get_flush_index()
  local s = session_ops.find_session(state._current)
  return s and s.last_flush_index or nil
end

local function save_flush_index(idx)
  local s = session_ops.find_session(state._current)
  if s then
    s.last_flush_index = idx
    store.save_index(state._index)
  end
end

M.get_flush_index  = get_flush_index
M.save_flush_index = save_flush_index
return M
