-- agent/session_cmds/parte_1.lua — exporta: do_new, do_reset, do_clear, do_status.
return function(M, N)
  local ui, session, mf, restart_mod, rebuild_ctx = N.ui, N.session, N.mf, N.restart_mod, N.rebuild_ctx


  function M.do_new(ctx)
    session.new()
    rebuild_ctx(ctx)
    session.set_model(ctx.active.ref)
    -- Nova sessão começa do zero: flush_state = 0
    -- Próximo flush acontecerá ao atingir flush_tokens normalmente.
    mf.marcar_flush(0)
    io.write("\27[38;5;114m✅ Nova sessão: " .. session.current() .. "\27[0m\n\n")
    io.flush()
  end


  function M.do_reset(ctx)
    io.write("\27[38;5;220m⚠️  Limpar conversa atual? (s/N): \27[0m")
    io.flush()
    local confirm = io.read()
    if confirm and confirm:lower() == "s" then
      session.reset()
      rebuild_ctx(ctx)
      -- Sessão resetada: reinicia ciclo de flush do zero
      mf.marcar_flush(0)
      io.write("\27[38;5;114m✅ Conversa resetada. Sessão: "
        .. session.current() .. "\27[0m\n\n")
    else
      io.write("\27[38;5;245mCancelado.\27[0m\n\n")
    end
    io.flush()
  end


  function M.do_clear(ctx)
    io.write("\27[38;5;203m⚠️  Deletar permanentemente a conversa atual? (s/N): \27[0m")
    io.flush()
    local confirm = io.read()
    if confirm and confirm:lower() == "s" then
      local next_id = session.delete_current()
      io.write("\27[38;5;114m✅ Conversa deletada. Migrando para: " .. next_id .. "\27[0m\n")
      io.write("\27[38;5;243mA TUI vai reiniciar...\27[0m\n\n")
      io.flush()
      restart_mod.restart_now()
    else
      io.write("\27[38;5;245mCancelado.\27[0m\n\n")
      io.flush()
    end
  end


  function M.do_status(ctx)
    local st = session.status()
    if not st then
      io.write("\27[38;5;203m❌ Nenhuma sessão ativa.\27[0m\n\n")
      io.flush(); return
    end
    local tw  = require("ui.core").tw()
    local sep = string.rep("─", tw)
    io.write("\27[38;5;238m" .. sep .. "\27[0m\n")
    io.write("\27[38;5;80m  Status da Sessão\27[0m\n")
    io.write("\27[38;5;238m" .. sep .. "\27[0m\n")
    local function row(label, value)
      io.write(string.format("  \27[38;5;245m%-18s\27[0m %s\n", label, value or "—"))
    end
    row("Sessão",           st.id)
    row("Chave",            st.key)
    row("Modelo",           st.model or ctx.active.ref or "—")
    row("Criada",           st.created_at)
    row("Última atividade", st.last_activity)
    if st.last_reset then row("Último reset", st.last_reset) end
    row("Mensagens",        tostring(st.msg_count))
    local pct = st.total_tokens > 0 and ctx.active.context_window > 0
      and math.floor(st.total_tokens / ctx.active.context_window * 100) or 0
    row("Tokens", string.format("%d / %d (%d%%)",
      st.total_tokens, ctx.active.context_window, pct))
    row("Compactações", tostring(st.compaction_count))
    io.write("\27[38;5;238m" .. sep .. "\27[0m\n\n")
    io.flush()
  end
end
