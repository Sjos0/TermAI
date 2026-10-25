-- agent/session_cmds/parte_2.lua — exporta: do_session.
return function(M, N)
  local session, tools, restart_mod = N.session, N.tools, N.restart_mod


  -- do_session — Gerencia listagem e troca de sessões.
  -- MODO INTERATIVO (/session): mostra lista numerada. O usuário digita o número.
  -- MODO DIRETO (/session <id>): troca imediatamente pelo ID fornecido.
  -- Em ambos os casos, após trocar a sessão ativa, a TUI é reiniciada para
  -- que o startup.lua carregue o histórico da nova sessão do zero, evitando
  -- mistura visual de contextos e garantindo renderização correta de tools.
  function M.do_session(ctx, switch_id)
    -- MODO DIRETO: /session <id> (compatibilidade com automações)
    if switch_id and switch_id ~= "" then
      local hist = session.switch(switch_id)
      if not hist then
        io.write("\27[38;5;203m❌ Sessão não encontrada: "
          .. switch_id .. "\27[0m\n\n")
        io.flush(); return
      end
      io.write("\27[38;5;114m✅ Sessão ativa alterada. Reiniciando TUI...\27[0m\n\n")
      io.flush()
      restart_mod.restart_now()
      return
    end

    -- MODO INTERATIVO: /session (menu numerado)
    local list = session.list()
    if #list == 0 then
      io.write("\27[38;5;245m Nenhuma sessão encontrada.\27[0m\n\n")
      io.flush(); return
    end

    io.write("\n" .. "\27[1m\27[38;5;80m  Gerenciador de Sessões\27[0m\n")
    io.write("\27[38;5;245m  " .. string.rep("─", 40) .. "\27[0m\n\n")

    for idx, s in ipairs(list) do
      local num    = string.format("%2d", idx)
      local marker = s.is_active and "\27[38;5;114m ●\27[0m " or "   "
      local id_col = s.is_active
        and ("\27[1m" .. s.id .. "\27[22m")
        or  ("\27[38;5;245m" .. s.id .. "\27[0m")
      local extra = ""
      if s.model            then extra = extra .. " · " .. s.model end
      if s.compaction_count > 0 then extra = extra .. " · " .. s.compaction_count .. " comp" end
      if s.last_activity ~= ""  then extra = extra .. " · " .. s.last_activity:sub(1, 10) end
      io.write("  \27[38;5;220m" .. num .. ".\27[0m" .. marker .. id_col
        .. "\27[38;5;245m  " .. s.msg_count .. " msgs" .. extra .. "\27[0m\n")
    end

    io.write("\n\27[38;5;245m  Digite o número da sessão para trocar (0 para voltar):\27[0m ")
    io.flush()
    local choice = io.read()
    local num = tonumber(choice)

    if not num or num == 0 then
      io.write("\27[38;5;245m  Cancelado.\27[0m\n\n")
      io.flush(); return
    end

    if num < 1 or num > #list then
      io.write("\27[38;5;203m  ❌ Opção inválida.\27[0m\n\n")
      io.flush(); return
    end

    local target = list[num]
    if target.is_active then
      io.write("\27[38;5;220m  ⚠️  Essa já é a sessão ativa.\27[0m\n\n")
      io.flush(); return
    end

    local hist = session.switch(target.id)
    if not hist then
      io.write("\27[38;5;203m  ❌ Falha ao acessar a sessão: "
        .. target.id .. "\27[0m\n\n")
      io.flush(); return
    end

    io.write("\27[38;5;114m  ✅ Trocando para " .. target.id
      .. ". Reiniciando TUI...\27[0m\n\n")
    io.flush()
    restart_mod.restart_now()
  end
end
