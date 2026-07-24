-- overflow_handler.lua — Bloco 6: Recuperação de overflow com resiliência.
-- Se o contexto excedeu o limite, tenta condensar antes de reenviar. Se a
-- condensação de emergência falhar, o histórico NÃO é destruído: o aviso é
-- mostrado e a requisição é tentada mesmo assim (ou o usuário usa /reset).
--
-- Único ponto de chamada de do_compaction que NÃO passava por
-- compaction_handler.lua — por isso o gatilho OVERFLOW não tinha nenhuma
-- guarda contra thrashing antes desta correção (REQ-9): troca
-- compact_mod.do_compaction por compact_mod.do_compaction_guarded, que
-- agora protege os dois gatilhos (AUTO e OVERFLOW) com o mesmo contador.
local banners     = require("agent.banners")
local ag_loop     = require("agent.loop")
local compact_mod = require("agent.compaction")
local timestamp   = require("agent.main_loop.timestamp")
local M = {}

local function handle(ctx, stamped_input, msgs_before, flush_msgs_start)
  io.write("\27[38;5;220m⚠️  Contexto excedido!"
    .. " Compactando com LLM e tentando novamente...\27[0m\n\n")
  io.flush()

  local mf_cfg = compact_mod.get_mf_config(ctx)
  banners.compactacao(ctx.tokens, mf_cfg)
  local compact_ok, motivo = compact_mod.do_compaction_guarded(ctx)
  local new_start = flush_msgs_start
  if compact_ok then
    -- Sucesso: contexto reduzido, podemos tentar novamente
    new_start = #ctx.msgs + 1
  else
    -- Falha crítica: não conseguimos reduzir o contexto.
    -- O histórico é preservado. A requisição provavelmente falhará
    -- novamente, mas pelo menos não perdemos dados.
    if motivo == "api_error" or motivo == "thrashing" then
      io.write("\27[38;5;203m   ❌ Compactação de emergência falhou."
        .. " O histórico foi preservado.\27[0m\n")
      io.write("\27[38;5;245m   Tente usar /reset para limpar o contexto"
        .. " ou aguarde a recuperação da API.\27[0m\n\n")
      io.flush()
    end
  end

  local new_msgs_before = #ctx.msgs
  local resp, elapsed, _, is_overflow, stream_complete, reasoning =
    ag_loop.rodar(ctx, stamped_input, "user")
  local end_time = timestamp.to_hhmm(timestamp.capture())
  return {
    msgs_before      = new_msgs_before,
    flush_msgs_start = new_start,
    resp             = resp,
    elapsed          = elapsed,
    is_overflow      = is_overflow,
    stream_complete  = stream_complete,
    reasoning        = reasoning,
    end_time         = end_time,
  }
end

M.handle = handle
return M
