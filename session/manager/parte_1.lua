-- session/manager/parte_1.lua — exporta: init, current, new, reset, delete_current.
return function(M, N)
  local generate, store, state, date_utils, reset_pol, sess_ops, orphan = N.generate, N.store, N.state, N.date_utils, N.reset_pol, N.sess_ops, N.orphan

  function M.init(session_config)
    state._config = session_config or {}
    store.ensure_dir()
    state._index = store.load_index()

    -- Recupera sessões órfãs (.jsonl no disco sem entrada no índice) ANTES
    -- de qualquer decisão sobre a sessão ativa — evita perda pós-restauração.
    orphan.scan()

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
end
