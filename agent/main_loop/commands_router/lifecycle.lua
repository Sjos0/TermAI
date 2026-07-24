-- lifecycle.lua — Comandos de ciclo de vida: sair (com flush de
-- encerramento), /config (recarrega config + restart), /compact
-- (compactação manual), /models (abre config de modelos + restart).
--
-- Correção de bug no /compact com foco: a versão antiga capturava
-- `instructions` mas não repassava pra do_compaction — o resumo real
-- saía sem o foco pedido. Pior: DEPOIS de compactar (que já persiste o
-- resumo de verdade via session.save_compaction dentro de do_compaction),
-- o código chamava session.save_compaction de NOVO, agora com o texto
-- literal "Compactação manual com foco: <instructions>" no lugar de
-- summary, e SEM o terceiro argumento (recent_msgs) — isso cai no branch
-- de fallback legado de messages.lua (append simples, sem o rewrite
-- atômico) e grava uma SEGUNDA entry type=compaction no arquivo, depois
-- da primeira. Como history.lua restaura sempre a ÚLTIMA entry
-- type=compaction, um restart depois de um /compact com foco carregava
-- essa string literal no lugar do resumo de verdade — perda de contexto
-- real. Corrigido: instructions vai direto pra do_compaction (REQ-11), e
-- a segunda chamada a save_compaction foi removida.
local ui          = require("ui")
local mf          = require("memoryflush")
local api         = require("agent.api")
local banners     = require("agent.banners")
local restart_mod = require("agent.restart")
local session     = require("session")
local compact_mod = require("agent.compaction")
local flush_mod   = require("agent.flush")
local persistence = require("agent.main_loop.persistence")
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"
local M = {}

local function route(input, ctx, flush_msgs_start)
  if input:lower() == "sair" or input:lower() == "/sair" then
    -- Hook de Saída Inteligente (Proactive Flush de Desligamento)
    if persistence.flush_ativo(ctx) then
      local pendentes = #ctx.msgs - flush_msgs_start + 1
      -- Executa o flush final se houver mais de 5 mensagens pendentes não arquivadas
      if pendentes > 5 then
        local mf_cfg = compact_mod.get_mf_config(ctx)
        banners.flush(ctx.tokens, mf_cfg, "Encerramento de sessão")
        io.flush()
        local new_msgs = {}
        for i = flush_msgs_start, #ctx.msgs do
          if ctx.msgs[i] then new_msgs[#new_msgs + 1] = ctx.msgs[i] end
        end
        local done = flush_mod.run(ctx, new_msgs, mf.get_flush_prompt(mf_cfg))
        if done then
          mf.marcar_flush(ctx.tokens)
          if session.save_flush_index then session.save_flush_index(#ctx.msgs) end
          io.write("\n\27[38;5;114m✅ Memória de encerramento salva com sucesso!\27[0m\n\n")
        else
          io.write("\n\27[38;5;203m⚠️  Falha no flush de encerramento. Dados mantidos na sessão.\27[0m\n\n")
        end
        io.flush()
      end
    end
    print("\nSaindo...")
    return { action = "break" }
  end

  if input == "/config" then
    local config_cmd = require("commands.config")
    config_cmd.run(ctx)
    -- Recarrega config do disco e limpa tela sem restart
    local config_mod = require("config")
    ctx.cfg      = config_mod.load()
    ctx.MAX_ITER = ctx.cfg.agents.defaults.maxIter or 20
    local req = ctx.cfg.agents.defaults.request or {}
    if req.timeout      then api.CURL_TIMEOUT  = req.timeout      end
    if req.max_retries  then api.MAX_RETRIES   = req.max_retries  end
    if req.retry_mode   then api.RETRY_MODE    = req.retry_mode   end
    if req.retry_static then api.RETRY_STATIC  = req.retry_static end
    restart_mod.restart_now()
    return { action = "continue" }
  end

  if input:match("^/compact") then
    local instructions = input:match("^/compact%s+(.+)$")
    local mf_cfg = compact_mod.get_mf_config(ctx)
    banners.compactacao(ctx.tokens, mf_cfg)
    -- REQ-11: foco customizável, propagado pra dentro de do_compaction —
    -- do_compaction já persiste o resumo real (com o foco aplicado) via
    -- session.save_compaction; não existe segunda chamada aqui.
    local sucesso, motivo = compact_mod.do_compaction(ctx, instructions)
    local new_start = flush_msgs_start
    if sucesso then
      new_start = #ctx.msgs + 1
      local msg = "✅ Compactação manual (State Reset) concluída."
      if instructions then msg = msg .. " Foco: " .. instructions end
      ui.ai_msg_stream(msg)
    else
      if motivo == "api_error" then
        io.write("\n\27[38;5;220m⚠️  Compactação manual abortada por falha na API."
          .. " O histórico foi preservado.\27[0m\n\n")
        io.flush()
      elseif motivo == "short_history" then
        io.write("\n\27[38;5;245mℹ️  Histórico curto demais para compactar.\27[0m\n\n")
        io.flush()
      elseif motivo == "empty_summary" then
        io.write("\n\27[38;5;220m⚠️  Compactação manual abortada: resumo vazio retornado pelo modelo."
          .. " O histórico foi preservado.\27[0m\n\n")
        io.flush()
      end
    end
    return { action = "continue", flush_msgs_start = new_start }
  end

  if input == "/models" then
    io.write("\n\27[38;5;114m⚙  Abrindo configurações de modelos...\27[0m\n")
    io.write("\27[38;5;243mA TUI vai reiniciar ao terminar.\27[0m\n\n")
    os.execute("lua " .. BASE .. "/main.lua models")
    restart_mod.restart_now()
    -- Sem goto continue no original: se restart_now() retornar,
    -- o input "/models" cai para o bloco 5 (requisição normal à API).
    return {}
  end

  return {}
end

M.route = route
return M
