-- agent/compaction/parte_3.lua — exporta: do_compaction_guarded.
return function(M, N)
  local mf, MAX_TENTATIVAS_SEM_PROGRESSO = N.mf, N.MAX_TENTATIVAS_SEM_PROGRESSO


  function M.do_compaction_guarded(ctx, custom_instructions)
    ctx._compactacoes_sem_progresso = ctx._compactacoes_sem_progresso or 0
    if ctx._compactacoes_sem_progresso >= MAX_TENTATIVAS_SEM_PROGRESSO then
      return false, "thrashing"
    end

    local mf_cfg = M.get_mf_config(ctx)

    if M.poda_mecanica(ctx) and not mf.deve_compactar(ctx.tokens, mf_cfg) then
      ctx._compactacoes_sem_progresso = 0
      return true, "poda_mecanica"
    end

    local sucesso, resultado = M.do_compaction(ctx, custom_instructions)

    if sucesso and not mf.deve_compactar(ctx.tokens, mf_cfg) then
      ctx._compactacoes_sem_progresso = 0
      return sucesso, resultado
    end

    ctx._compactacoes_sem_progresso = ctx._compactacoes_sem_progresso + 1
    return sucesso, resultado
  end
end
