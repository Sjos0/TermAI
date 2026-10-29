-- agent/api/request_stream/streamer/fallback.lua — fallback de modelo e fechamento da falha de pensar_stream.
local recovery = require("agent.api.request_stream.recovery")

return function(M)
  local M_ = {}

  -- Tenta cada modelo de fallback. Devolve (resultado_empacotado, nil) em sucesso,
  -- ou (nil, last_error) quando nenhum fallback responde.
  function M_.tentar_fallbacks(ctx, role, last_error, rcfg)
    if ctx._fallback_suppress then return nil, last_error end
        local model_cfg = ctx.cfg and ctx.cfg.agents and ctx.cfg.agents.defaults
                          and ctx.cfg.agents.defaults.model or {}
        local fallbacks = model_cfg.fallbacks or {}
        local original_active = ctx.active
        for _, ref in ipairs(fallbacks) do
          if type(ref) == "string" and ref ~= "" and ref ~= original_active.ref then
            local ok_models, models_mod = pcall(require, "models")
            local resolved = nil
            if ok_models then resolved = models_mod.resolve(ref) end
            if resolved then
              io.write("\n\27[38;5;220m[modelo] Falha em "
                .. tostring(original_active.ref) .. "; tentando fallback "
                .. tostring(ref) .. " após " .. tostring(rcfg.max_retries)
                .. " tentativas.\27[0m\n")
              io.flush()
              ctx.active = resolved
              ctx._fallback_suppress = true
              local result = table.pack(M.pensar_stream(ctx, nil, role))
              ctx._fallback_suppress = nil
              if result[1] and not tostring(result[1]):match("^%[ERRO")
                 and result[2] ~= true then
                io.write("\27[38;5;114m[modelo] Fallback ativo nesta sessão: "
                  .. tostring(ref) .. "\27[0m\n")
                io.flush()
                return result, nil
              end
              last_error = "fallback " .. tostring(ref) .. " falhou: "
                         .. tostring(result[1] or "sem resposta")
            end
          end
        end
        ctx.active = original_active
    return nil, last_error
  end

  -- Fechamento quando a requisição inteira falhou (sem stream para truncar).
  function M_.falha_final(ctx, rcfg, last_error)
      -- Não removemos a mensagem do usuário: falha de rede não apaga o que digitou.
    local ui = require("ui")
    if ui.clear_retry_lines then ui.clear_retry_lines() end
    recovery.recover_tool_seq(ctx.msgs)
    local msg = "Falha após " .. rcfg.max_retries .. " tentativas — " .. tostring(last_error or "")
    if ui.show_api_error then
      ui.show_api_error(msg)
    end
      -- done_flag = nil: não houve stream (evita "Resposta incompleta" enganoso).
    return "[ERRO] " .. msg, false, nil, ""
  end

  return M_
end
