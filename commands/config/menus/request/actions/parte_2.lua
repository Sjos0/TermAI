-- commands/config/menus/request/actions/parte_2.lua — exporta: change_request_mode, change_reasoning_effort, change_language, change_thinking_effort.
return function(M, N)
  local ui, saver, c = N.ui, N.saver, N.c


  function M.change_request_mode(ctx)
    io.write("\n")
    io.write("  "..c.white.."1."..c.reset.."  stream  "..c.dim.."(curl direto - tokens em tempo real, padrao)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  buffer  "..c.dim.."(wrapper - cancela se servidor nao responde)"..c.reset.."\n\n")
    local mch = ui.prompt_read("Modo (1/2)")
    if mch == "1" then
      saver.save_req(ctx, "mode", "stream")
      io.write(c.green.."\n  Modo: stream\n"..c.reset)
    elseif mch == "2" then
      saver.save_req(ctx, "mode", "buffer")
      local cur_wt = (ctx.cfg.agents.defaults.request or {}).wait_timeout or 0
      if cur_wt == 0 then
        saver.save_req(ctx, "wait_timeout", 25)
        io.write(c.green.."\n  Modo: buffer\n"..c.reset)
        io.write(c.yellow.."  wait_timeout era 0 - auto-configurado para 25s.\n"..c.reset)
      else
        io.write(c.green.."\n  Modo: buffer (wait: "..cur_wt.."s)\n"..c.reset)
      end
    else
      io.write(c.gray.."\n  Cancelado.\n"..c.reset)
    end
    ui.pause()
  end


  function M.change_reasoning_effort(ctx)
    io.write("\n"..c.gray.."  Reasoning Effort (OpenRouter) — só afeta modelos com reasoning_style=openrouter"..c.reset.."\n")
    io.write("  "..c.white.."1."..c.reset.."  high     "..c.dim.."(Profundo)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  medium   "..c.dim.."(Equilibrado - Padrão)"..c.reset.."\n")
    io.write("  "..c.white.."3."..c.reset.."  low      "..c.dim.."(Leve)"..c.reset.."\n")
    io.write("  "..c.white.."4."..c.reset.."  xhigh    "..c.dim.."(Máximo)"..c.reset.."\n")
    io.write("  "..c.white.."5."..c.reset.."  minimal  "..c.dim.."(Básico)"..c.reset.."\n")
    io.write("  "..c.white.."6."..c.reset.."  none     "..c.dim.."(Desativado)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
    local lch = ui.prompt_read("Escolha")
    local efforts = {["1"]="high",["2"]="medium",["3"]="low",["4"]="xhigh",["5"]="minimal",["6"]="none"}
    if efforts[lch] then
      saver.save_req(ctx, "reasoning_effort", efforts[lch])
      io.write(c.green.."\n  ✅ Effort: "..efforts[lch].."\n"..c.reset)
    else 
      io.write(c.gray.."\n  Cancelado.\n"..c.reset) 
    end
    ui.pause()
  end


  function M.change_language(ctx)
    io.write("\27[2J\27[H") -- Clear screen
    io.flush()
    -- Régua responsiva (#331): calculada agora, nunca congelada no load.
    local SEP = require("ui.core").regua(45, 2)

    io.write("\n"..c.bold..c.cyan.."  Configurações › Idioma do Agente"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write("  "..c.white.."1."..c.reset.."  Portuguese (Português - Padrão)\n")
    io.write("  "..c.white.."2."..c.reset.."  English (Inglês)\n")
    io.write("  "..c.white.."3."..c.reset.."  Spanish (Español)\n")
    io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
    local lch = ui.prompt_read("Escolha")
    local langs = {["1"]="Portuguese", ["2"]="English", ["3"]="Spanish"}
    if langs[lch] then
      saver.save_req(ctx, "language", langs[lch])
      io.write(c.green.."\n  ✅ Idioma do Agente configurado para: "..langs[lch].."\n"..c.reset)
    else 
      io.write(c.gray.."\n  Cancelado.\n"..c.reset) 
    end
    ui.pause()
  end


  function M.change_thinking_effort(ctx)
    -- Valores confirmados na documentação oficial do Hy3 (Tencent): não
    -- existe "xhigh" documentado pra esse modelo — só 3 níveis reais.
    io.write("\n"..c.gray.."  Thinking Effort (OpenCode Zen) — afeta hy3-free e outros reasoning_effort"..c.reset.."\n")
    io.write("  "..c.white.."1."..c.reset.."  Non-think   "..c.dim.."(no_think — respostas rápidas, sem raciocínio)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  Think       "..c.dim.."(low — raciocínio leve)"..c.reset.."\n")
    io.write("  "..c.white.."3."..c.reset.."  Think High  "..c.dim.."(high — raciocínio profundo, padrão recomendado)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
    local tch = ui.prompt_read("Escolha")
    local tefforts = {["1"]="no_think",["2"]="low",["3"]="high"}
    if tefforts[tch] then
      saver.save_defaults(ctx, "thinkingEffort", tefforts[tch])
      io.write(c.green.."\n  ✅ Thinking Effort: "..tefforts[tch].."\n"..c.reset)
    else
      io.write(c.gray.."\n  Cancelado.\n"..c.reset)
    end
    ui.pause()
  end
end
