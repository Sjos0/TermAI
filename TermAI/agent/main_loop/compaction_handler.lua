-- compaction_handler.lua — Bloco 1: Auto-Compaction (State Condensation).
-- Dispara quando o contexto atinge o limite configurado. Retorna o novo
-- flush_msgs_start se a condensação for bem-sucedida; caso contrário retorna
-- o valor recebido inalterado e o histórico permanece 100% preservado.
--
-- Correção de bug: a versão antiga checava persistence.flush_ativo(ctx)
-- ANTES de tentar compactar — isso acoplava auto-compactação ao Memory
-- Flush (sistema diferente: arquivamento periódico de longo prazo). Se o
-- usuário desativasse o Flush (flush_enabled=false) ou não tivesse
-- flush_tokens configurado, a auto-compactação também parava de rodar,
-- deixando o contexto crescer sem proteção nenhuma. Removido — a
-- compactação depende só de mf.deve_compactar (limite de tokens).
local mf          = require("memoryflush")
local banners     = require("agent.banners")
local compact_mod = require("agent.compaction")
local M = {}

local function handle(ctx, flush_msgs_start)
  local mf_cfg = compact_mod.get_mf_config(ctx)
  if not mf.deve_compactar(ctx.tokens, mf_cfg) then
    return { flush_msgs_start = flush_msgs_start }
  end

  -- Dispara o banner visual informativo unificado do Termux
  banners.compactacao(ctx.tokens, mf_cfg)

  -- REQ-9+REQ-10: poda mecânica primeiro (sem custo de LLM); se não for
  -- suficiente, compacta via LLM com guarda anti-thrashing.
  local sucesso, resultado = compact_mod.do_compaction_guarded(ctx)

  if sucesso then
    if resultado == "poda_mecanica" then
      io.write("\n\27[38;5;114m✅ Poda mecânica liberou espaço — compactação via LLM não foi necessária.\27[0m\n\n")
    else
      io.write("\n\27[38;5;114m✅ Compactação concluída. Histórico de tokens otimizado para a sessão!\27[0m\n\n")
    end
    io.flush()
    return { flush_msgs_start = #ctx.msgs + 1 }
  end

  if resultado == "api_error" then
    io.write("\n\27[38;5;220m⚠️  A compactação foi abortada por falha na API."
      .. " O histórico foi protegido e mantido intacto.\27[0m\n\n")
    io.flush()
  elseif resultado == "empty_summary" then
    io.write("\n\27[38;5;220m⚠️  A compactação foi abortada: resumo vazio retornado pelo modelo."
      .. " O histórico foi protegido e mantido intacto.\27[0m\n\n")
    io.flush()
  elseif resultado == "thrashing" then
    io.write("\n\27[38;5;203m❌ Compactação pausada: mesmo após tentativas consecutivas + poda"
      .. " mecânica, o contexto continua acima do limite (provável mensagem única muito grande"
      .. " dentro da janela recente protegida). Histórico intacto — revise manualmente"
      .. " (ex: /compact ou ajuste keep_recent_tokens).\27[0m\n\n")
    io.flush()
  end
  return { flush_msgs_start = flush_msgs_start }
end

M.handle = handle
return M
