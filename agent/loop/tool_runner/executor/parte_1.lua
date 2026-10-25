-- agent/loop/tool_runner/executor/parte_1.lua — exporta: run_batch.
return function(M, N)
  local is_read_call, executar_individual, executar_grupo_read = N.is_read_call, N.executar_individual, N.executar_grupo_read


  function M.run_batch(ctx, tool_calls)
    local i, n = 1, #tool_calls
    while i <= n do
      local tc      = tool_calls[i]
      local run_len = 1
      if is_read_call(tc) and not ctx.is_subagent then
        local j = i
        while j <= n and is_read_call(tool_calls[j]) do j = j + 1 end
        run_len = j - i
      end
      if run_len >= 2 then
        local group = {}
        for k = i, i + run_len - 1 do group[#group + 1] = tool_calls[k] end
        executar_grupo_read(ctx, group)
        if ctx.tool_cancelled then break end
        i = i + run_len
      else
        executar_individual(ctx, tc)
        if ctx.tool_cancelled then break end
        i = i + 1
      end
    end
  end
end
