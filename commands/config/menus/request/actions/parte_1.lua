-- commands/config/menus/request/actions/parte_1.lua — exporta: change_timeout, change_max_retries, change_retry_mode, restore_defaults, change_wait_timeout.
return function(M, N)
  local ui, api, saver, c = N.ui, N.api, N.saver, N.c


  function M.change_timeout(ctx)
    local s = ui.prompt_read("Timeout em segundos (0 = sem limite)")
    local v = tonumber(s)
    if v and v >= 0 then
      local t = (v == 0) and 999999 or v
      saver.save_req(ctx, "timeout", t)
      api.CURL_TIMEOUT = t
      io.write(c.green.."\n  ✅ Timeout: "..(v==0 and "sem limite" or (v.."s")).."\n"..c.reset)
    else 
      io.write(c.red.."\n  ❌ Inválido.\n"..c.reset) 
    end
    ui.pause()
  end


  function M.change_max_retries(ctx)
    local s = ui.prompt_read("Número máximo de tentativas (1-20)")
    local v = tonumber(s)
    if v and v >= 1 and v <= 20 then
      saver.save_req(ctx, "max_retries", v)
      api.MAX_RETRIES = v
      io.write(c.green.."\n  ✅ Max tentativas: "..v.."\n"..c.reset)
    else 
      io.write(c.red.."\n  ❌ Inválido (1-20).\n"..c.reset) 
    end
    ui.pause()
  end


  function M.change_retry_mode(ctx)
    io.write("  "..c.white.."1."..c.reset.."  exponential  "..c.dim.."(1s, 2s, 4s, 8s... dobra até o máximo)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  static        "..c.dim.."(mesmo intervalo em toda tentativa)"..c.reset.."\n\n")
    local mch = ui.prompt_read("Escolha modo")
    if mch == "1" then
      saver.save_req(ctx, "retry_mode", "exponential")
      api.RETRY_MODE = "exponential"
      local mx = ui.prompt_read("Tempo máximo de espera em segundos (padrão: 30)")
      local mv = tonumber(mx)
      if mv and mv >= 1 then
        saver.save_req(ctx, "retry_max", mv)
        api.RETRY_MAX = mv
      end
      io.write(c.green.."\n  ✅ Modo: exponential\n"..c.reset)
    elseif mch == "2" then
      saver.save_req(ctx, "retry_mode", "static")
      api.RETRY_MODE = "static"
      local sv = ui.prompt_read("Intervalo fixo em segundos (ex: 5)")
      local s2 = tonumber(sv)
      if s2 and s2 >= 1 then
        saver.save_req(ctx, "retry_static", s2)
        api.RETRY_STATIC = s2
      end
      io.write(c.green.."\n  ✅ Modo: static  (".. (tonumber(sv) or 5) .."s)\n"..c.reset)
    end
    ui.pause()
  end


  function M.restore_defaults(ctx)
    saver.save_req(ctx, "timeout", 120)
    saver.save_req(ctx, "max_retries", 10)
    saver.save_req(ctx, "retry_mode", "exponential")
    saver.save_req(ctx, "retry_max", 30)
    saver.save_req(ctx, "mode", "stream")
    saver.save_req(ctx, "reasoning_effort", "medium")
    api.CURL_TIMEOUT = 120
    api.MAX_RETRIES  = 10
    api.RETRY_MODE   = "exponential"
    api.RETRY_MAX    = 30
    io.write(c.green.."\n  ✅ Padrões restaurados.\n"..c.reset)
    ui.pause()
  end


  function M.change_wait_timeout(ctx)
    local s = ui.prompt_read("Wait timeout em segundos (cancela se servidor nao responde, 5-120)")
    local v = tonumber(s)
    if v and v >= 5 and v <= 120 then
      saver.save_req(ctx, "wait_timeout", v)
      io.write(c.green.."\n  ✅ Wait timeout: "..v.."s\n"..c.reset)
    else 
      io.write(c.red.."\n  ❌ Invalido (5-120s).\n"..c.reset) 
    end
    ui.pause()
  end
end
