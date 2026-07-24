-- session_ops.lua — Busca, criação, listagem, status e modelo de sessões.
local state      = require("session.manager.state")
local date_utils = require("session.manager.date_utils")
local generate   = require("session.generate")
local store      = require("session.store")
local M = {}

local function find_session(id)
  for _, s in ipairs(state._index.sessions) do
    if s.id == id then return s end
  end
  return nil
end

local function create_session_entry()
  local id = generate.id()
  state._index.sessions[#state._index.sessions + 1] = {
    id               = id,
    key              = generate.key(),
    created_at       = date_utils.now_iso(),
    updated_at       = date_utils.now_iso(),
    last_activity    = date_utils.now_iso(),
    last_reset       = nil,
    msg_count        = 0,
    total_tokens     = 0,
    compaction_count = 0,
    model            = nil,
  }
  return id
end

local function set_model(model_ref)
  local s = find_session(state._current)
  if s then s.model = model_ref; store.save_index(state._index) end
end

local function list()
  local result = {}
  for _, s in ipairs(state._index.sessions) do
    result[#result + 1] = {
      id               = s.id,
      msg_count        = s.msg_count        or 0,
      tokens           = s.total_tokens     or 0,
      compaction_count = s.compaction_count or 0,
      last_activity    = s.last_activity    or s.updated_at or "",
      last_reset       = s.last_reset,
      model            = s.model,
      is_active        = (s.id == state._current),
    }
  end
  return result
end

local function status()
  local s = find_session(state._current)
  if not s then return nil end
  return {
    id               = s.id,
    key              = s.key or generate.key(),
    created_at       = s.created_at       or "",
    updated_at       = s.updated_at       or "",
    last_activity    = s.last_activity    or s.updated_at or "",
    last_reset       = s.last_reset,
    msg_count        = s.msg_count        or 0,
    total_tokens     = s.total_tokens     or 0,
    compaction_count = s.compaction_count or 0,
    model            = s.model,
  }
end

M.find_session         = find_session
M.create_session_entry = create_session_entry
M.set_model            = set_model
M.list                 = list
M.status               = status
return M
