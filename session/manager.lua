-- session/manager.lua — Fachada + Orquestrador do sistema de sessões.
-- Interface pública inalterada: M.init, M.current, M.load_history,
-- M.save_message, M.save_compaction, M.set_model, M.new, M.reset,
-- M.list, M.switch, M.status, M.cleanup, M.get_flush_index, M.save_flush_index
local generate   = require("session.generate")
local store      = require("session.store")
local state      = require("session.manager.state")
local date_utils = require("session.manager.date_utils")
local reset_pol  = require("session.manager.reset_policy")
local sess_ops   = require("session.manager.session_ops")
local hist       = require("session.manager.history")
local msgs       = require("session.manager.messages")
local flush      = require("session.manager.flush_index")
local cleanup    = require("session.manager.cleanup")
local M = {}

function M.init(session_config)
  state._config = session_config or {}
  store.ensure_dir()
  state._index = store.load_index()

  if not state._index.active or not sess_ops.find_session(state._index.active) then
    local id = sess_ops.create_session_entry()
    state._index.active = id
    store.save_index(state._index)
  end
  state._current = state._index.active
  store.write_header(state._current, generate.key())

  local mc = state._config.maintenance or {}
  if mc.auto_cleanup then M.cleanup(false) end

  local s = sess_ops.find_session(state._current)
  if s then
    if reset_pol.needs_daily_reset(s) then
      local old    = state._current
      local new_id = sess_ops.create_session_entry()
      local ns     = sess_ops.find_session(new_id)
      if ns then ns.last_reset = "daily:" .. date_utils.now_iso() end
      state._index.active = new_id
      state._current      = new_id
      store.save_index(state._index)
      store.write_header(state._current, generate.key())
      return { reason = "daily", from = old, to = state._current }
    elseif reset_pol.needs_idle_reset(s) then
      local old    = state._current
      local new_id = sess_ops.create_session_entry()
      local ns     = sess_ops.find_session(new_id)
      if ns then ns.last_reset = "idle:" .. date_utils.now_iso() end
      state._index.active = new_id
      state._current      = new_id
      store.save_index(state._index)
      store.write_header(state._current, generate.key())
      return { reason = "idle", from = old, to = state._current }
    end
  end
  return nil
end

function M.current()
  return state._current
end

function M.new()
  local id = sess_ops.create_session_entry()
  state._index.active = id
  state._current      = id
  store.save_index(state._index)
  store.write_header(state._current, generate.key())
  return id
end

function M.reset()
  store.delete_file(state._current)
  local s = sess_ops.find_session(state._current)
  if s then
    s.msg_count        = 0
    s.total_tokens     = 0
    s.compaction_count = 0
    s.updated_at       = date_utils.now_iso()
    s.last_activity    = date_utils.now_iso()
  end
  store.save_index(state._index)
  store.write_header(state._current, generate.key())
end

-- Deleta permanentemente a sessão atual do disco e do índice,
-- migrando automaticamente para a sessão mais recente restante.
-- Se não houver nenhuma, cria uma nova sessão limpa.
function M.delete_current()
  store.delete_file(state._current)
  local sessions = state._index.sessions
  local removed_idx = nil
  for i, s in ipairs(sessions) do
    if s.id == state._current then removed_idx = i; break end
  end
  if removed_idx then table.remove(sessions, removed_idx) end

  local next_session_id = nil
  if #sessions > 0 then
    local sorted = {}
    for _, s in ipairs(sessions) do sorted[#sorted + 1] = s end
    table.sort(sorted, function(a, b)
      local t_a = date_utils.parse_iso(a.last_activity or a.updated_at or "") or 0
      local t_b = date_utils.parse_iso(b.last_activity or b.updated_at or "") or 0
      return t_a > t_b
    end)
    next_session_id = sorted[1].id
  else
    next_session_id = sess_ops.create_session_entry()
  end

  state._index.active, state._current = next_session_id, next_session_id
  store.save_index(state._index)
  store.write_header(state._current, generate.key())
  return next_session_id
end

function M.switch(target_id)
  if not sess_ops.find_session(target_id) then return nil end
  state._index.active = target_id
  state._current      = target_id
  store.write_header(state._current, generate.key())
  local s = sess_ops.find_session(state._current)
  if s then s.last_activity = date_utils.now_iso() end
  store.save_index(state._index)
  return M.load_history()
end

-- Re-exports: interface pública delega para submódulos especializados
M.load_history    = hist.load_history
M.save_message    = msgs.save_message
M.save_compaction = msgs.save_compaction
M.get_last_compaction = msgs.get_last_compaction
M.set_model       = sess_ops.set_model
M.list            = sess_ops.list
M.status          = sess_ops.status
M.cleanup         = cleanup.cleanup
M.get_flush_index  = flush.get_flush_index
M.save_flush_index = flush.save_flush_index

-- v3: persiste último ctx.tokens conhecido em registro meta dedicado.
-- Isso separa "mensagens" de "estado da sessão" e evita que o valor
-- fique preso à frágil definição de "última mensagem" do persistence.lua.
function M.save_session_tokens(tokens, fresh)
  if not tokens or tokens <= 0 then return end
  if fresh == nil then fresh = true end  -- default: confiável (compat retroativa)
  local s = sess_ops.find_session(state._current)
  if s and s.total_tokens and s.total_tokens >= tokens then return end
  store.append_entry(state._current, {
    type        = "session_tokens",
    tokens      = tokens,
    fresh       = fresh,
    timestamp   = date_utils.now_iso(),
  })
  if s then
    s.total_tokens = tokens
    s.updated_at   = date_utils.now_iso()
  end
  store.save_index(state._index)
end

-- v3: carrega último token persistido de forma confiável.
-- Percorre entries de trás pra frente procurando:
--   1. type=session_tokens (campo meta dedicado — mais confiável)
--   2. type=message com tokens > 0 (fallback legado)
function M.load_session_tokens()
  local entries = store.read_entries(state._current)
  for i = #entries, 1, -1 do
    local e = entries[i]
    if e.type == "session_tokens" and e.tokens and e.tokens > 0 then
      -- v4: retorna tokens + fresh (compat retroativa: sem campo = true)
      local fresh = e.fresh
      if fresh == nil then fresh = true end
      return e.tokens, fresh
    end
    if e.type == "message" and e.tokens and e.tokens > 0 then
      -- Fallback legado: entry de mensagem não tem fresh, assume true
      return e.tokens, true
    end
  end
  return 0, false
end

return M
