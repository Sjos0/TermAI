-- session/manager/parte_2.lua — exporta: switch, load_history, save_message, save_compaction, get_last_compaction, set_model, list, status, cleanup, get_flush_index, save_flush_index, save_session_tokens, load_session_tokens.
return function(M, N)
  local generate, store, state, date_utils, sess_ops, hist, msgs, flush, cleanup = N.generate, N.store, N.state, N.date_utils, N.sess_ops, N.hist, N.msgs, N.flush, N.cleanup


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
end
