-- agent/compaction/parte_2.lua — exporta: do_compaction.
return function(M, N)
  local api, session, mf, cutpoint, serialize, summary_merge, filetracking, confirm, splitturn, CUSTOM_INSTRUCTIONS_MAX_CHARS, sanitize_roles = N.api, N.session, N.mf, N.cutpoint, N.serialize, N.summary_merge, N.filetracking, N.confirm, N.splitturn, N.CUSTOM_INSTRUCTIONS_MAX_CHARS, N.sanitize_roles


  function M.do_compaction(ctx, custom_instructions)
    local tokens_before = ctx.tokens
    local c = ctx.compaction or {}

    if custom_instructions and #custom_instructions > CUSTOM_INSTRUCTIONS_MAX_CHARS then
      custom_instructions = custom_instructions:sub(1, CUSTOM_INSTRUCTIONS_MAX_CHARS)
    end

    local safe_start, safe_end = cutpoint.find_compaction_bounds(ctx.msgs, {
      anchor_keep        = c.anchor_keep or 5,
      anchor_token_cap   = c.anchor_token_cap or 8000,
      keep_recent_tokens = c.keep_recent_tokens or 20000,
    }, api.estimate_tokens)
    if not safe_start then return false, safe_end end

    local discarded = {}
    for i = safe_start + 1, safe_end - 1 do
      if ctx.msgs[i] then discarded[#discarded + 1] = ctx.msgs[i] end
    end
    if #discarded == 0 then return false, "short_history" end

    local prev_summary, prev_details = summary_merge.get_previous(session)

    local compaction_active = ctx.active
    if c.compaction_model then
      compaction_active = {}
      for k, v in pairs(ctx.active) do compaction_active[k] = v end
      compaction_active.model_id = c.compaction_model
    end
    -- REQ-6: teto do resumo = max_tokens do modelo configurado.
    if c.compaction_max_tokens then
      compaction_active.max_tokens = c.compaction_max_tokens
    end

    local function build_summary_prompt(serialized)
      return summary_merge.build_prompt(serialized, prev_summary, custom_instructions)
    end

    -- REQ-2: se safe_end cai no meio de um turno (não é um "user" limpo),
    -- separa em história completa + início do turno cortado, e gera os
    -- dois resumos separadamente.
    local turn_start = splitturn.find_turn_start(ctx.msgs, safe_end, safe_start)
    local processed_summary, confirmado

    if turn_start < safe_end then
      local history_msgs, prefix_msgs = {}, {}
      for i = safe_start + 1, turn_start - 1 do history_msgs[#history_msgs + 1] = ctx.msgs[i] end
      for i = turn_start, safe_end - 1 do prefix_msgs[#prefix_msgs + 1] = ctx.msgs[i] end
      processed_summary, confirmado = splitturn.gerar_resumo_dividido(
        history_msgs, prefix_msgs, build_summary_prompt,
        { pensar_stream = api.pensar_stream, serialize = serialize, confirm = confirm,
          comp_active = compaction_active, cfg = ctx.cfg, max_tentativas = c.confirm_max_tentativas })
    else
      local serialized_history = serialize.serialize_messages(discarded)
      local function build_comp_ctx()
        local system_prompt, user_content = build_summary_prompt(serialized_history)
        return {
          cfg = ctx.cfg, active = compaction_active, tokens = 0, no_tools = true,
          msgs = {
            { role = "system", content = system_prompt },
            { role = "user",   content = user_content },
            { role = "assistant", content = "Histórico recebido. Iniciando compactação..." }
          }
        }
      end
      processed_summary, confirmado = confirm.gerar_e_confirmar(
        api.pensar_stream, build_comp_ctx, compaction_active, ctx.cfg, c.confirm_max_tentativas)
    end

    if not processed_summary then
      io.write("\n\27[38;5;203m[FAIL] Falha na compactação: nenhuma tentativa de resumo foi gerada.\27[0m\n\n")
      io.flush()
      return false, "api_error"
    end
    if not confirmado then
      io.write("\n\27[38;5;220m[WARN] Resumo não confirmado no turno de verificação — usando a melhor versão gerada.\27[0m\n\n")
      io.flush()
    end

    local attention_xml, details = filetracking.accumulate(prev_details, ctx.session_files)

    local new_msgs = {}
    for i = 1, safe_start do new_msgs[#new_msgs + 1] = ctx.msgs[i] end
    new_msgs[#new_msgs + 1] = {
      role    = "user",
      content = "[ESTADO DO SISTEMA CONDENSADO]\n\n" .. processed_summary .. attention_xml
    }
    for i = safe_end, #ctx.msgs do new_msgs[#new_msgs + 1] = ctx.msgs[i] end

    local persisted_source = {}
    for i = 1, safe_start do persisted_source[#persisted_source + 1] = ctx.msgs[i] end
    for i = safe_end, #ctx.msgs do persisted_source[#persisted_source + 1] = ctx.msgs[i] end

    ctx.msgs = sanitize_roles(new_msgs)
    ctx.tokens = api.estimate_tokens(ctx.msgs)

    local persisted_msgs = sanitize_roles(persisted_source)
    session.save_compaction(processed_summary, tokens_before, persisted_msgs, details)
    session.save_session_tokens(ctx.tokens, true)
    mf.marcar_flush(ctx.tokens)

    local misc = require("ui.misc")
    local end_time = os.date("%H:%M")
    misc.footer(ctx.tokens, ctx.active.context_window, 0, end_time)

    return true, processed_summary
  end
end
