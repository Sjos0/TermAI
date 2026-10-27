-- ui/stream/fluxo.lua — início, confirmação, tokens e fim do streaming.
return function(M, N)
  local spinner, state, box, get_thinking_mode = N.spinner, N.state, N.box, N.get_thinking_mode
  function M.stream_start()
    if N.ESTADO.sink then return N.ESTADO.sink.start() end
    state.reset()
  end

  -- Chamado pelo streamer no instante em que o primeiro chunk válido da
  -- tentativa chega (reasoning, content OU tool_call — não importa o tipo).
  -- É o único ponto que sabe, de fato, que a fase de retry/spinner acabou.

  function M.stream_confirm()
    if N.ESTADO.sink then return N.ESTADO.sink.confirm() end
    local s = state._s
    if s.started then return end
    local tmode = get_thinking_mode()
    if tmode ~= "compact" then
      spinner.kill_spinner()
    end
    spinner.clear_retry_lines()
    s.started = true
  end


  function M.stream_token(tok)
    if N.ESTADO.sink then return N.ESTADO.sink.token(tok) end
    require("ui.spinner.rotulo").evento("agent_turn")
    local s = state._s
    local tmode = get_thinking_mode()
    if tmode == "compact" then
      if not s.compact_thinking_stopped then
        s.compact_thinking_stopped = true
        if require("ui.spinner.rotulo").regiao_ativa() then
          spinner.finish_reasoning_region()
        else
          spinner.stop_thinking_and_print_compact()
        end
      end
    else
      if s.reasoning_started then
        box.close_reasoning_box()
        s.reasoning_started = false
      end
    end
    s.full = s.full .. tok
  end

  -- MUDANÇA: retorna full E reasoning.
  -- reasoning vai para o JSONL (exibição na recuperação).
  -- Não entra em ctx.msgs — a API rejeitaria.
  function M.stream_end()
    if N.ESTADO.sink then return N.ESTADO.sink.finish() end
    local s = state._s
    local tmode = get_thinking_mode()
    if tmode == "compact" then
      if not s.compact_thinking_stopped then
        s.compact_thinking_stopped = true
        if require("ui.spinner.rotulo").regiao_ativa() then
          spinner.finish_reasoning_region()
        else
          spinner.stop_thinking_and_print_compact()
        end
      end
    else
      if s.reasoning_started then
        box.close_reasoning_box()
        s.reasoning_started = false
      end
    end
    return s.full, s.reasoning or ""
  end

end
