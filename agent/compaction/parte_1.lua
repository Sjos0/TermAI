-- agent/compaction/parte_1.lua — exporta: get_mf_config, poda_mecanica.
return function(M, N)
  local api, poda = N.api, N.poda



  function M.get_mf_config(ctx)
    local c = ctx.compaction or {}
    return {
      max_contexto = ctx.active.context_window,
      limites = {
        flush_tokens    = c.flush_tokens    or 40000,
        compactacao_pct = c.compactacao_pct or 0.9,
        reserve_tokens  = c.reserve_tokens  or 16384,
        flush_prompt    = c.flush_prompt    or "",
        flush_enabled   = c.flush_enabled,
      }
    }
  end


  function M.poda_mecanica(ctx)
    local c = ctx.compaction or {}
    local ok = poda.poda_mecanica(
      ctx.msgs,
      c.keep_recent_tokens or 20000,
      c.poda_max_chars or 500,
      api.estimate_tokens
    )
    if ok then
      ctx.tokens = api.estimate_tokens(ctx.msgs)
    end
    return ok
  end
end
