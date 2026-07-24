-- flush_handler.lua — Bloco 3: Memory Flush pré-input (contexto isolado).
-- Dispara quando o limite de tokens desde o último flush é atingido. Envia
-- SOMENTE as mensagens novas (flush_msgs_start → #ctx.msgs) para o agente de
-- flush, nunca o histórico completo — isso evita alucinação.
local mf          = require("memoryflush")
local banners     = require("agent.banners")
local session     = require("session")
local compact_mod = require("agent.compaction")
local flush_mod   = require("agent.flush")
local persistence = require("agent.main_loop.persistence")
local M = {}

local function handle(ctx, input, flush_msgs_start)
  if not persistence.flush_ativo(ctx) then
    return { flush_msgs_start = flush_msgs_start }
  end

  local mf_cfg = compact_mod.get_mf_config(ctx)
  local est    = math.ceil(#input / 4)
  if not mf.deve_flush(ctx.tokens + est, mf_cfg) then
    return { flush_msgs_start = flush_msgs_start }
  end

  local preview = #input > 60 and input:sub(1, 57) .. "..." or input
  banners.flush(ctx.tokens, mf_cfg, preview)

  -- Coleta apenas mensagens NOVAS desde o último flush
  local new_msgs = {}
  for i = flush_msgs_start, #ctx.msgs do
    if ctx.msgs[i] then new_msgs[#new_msgs + 1] = ctx.msgs[i] end
  end

    local done = flush_mod.run(ctx, new_msgs, mf.get_flush_prompt(mf_cfg))
    if done then
      -- Fix #23: recalcula ctx.tokens pós-flush para evitar valor defasado no footer
      local utils_ok, utils = pcall(require, "agent.api.utils")
      if utils_ok and utils.ensure_tokens then utils.ensure_tokens(ctx) end
      if session.save_flush_index then session.save_flush_index(#ctx.msgs) end
      -- Emite evento OnMemoryFlush para scripts do usuário em ~/.TermAI/hooks/
      local ok_he, he = pcall(require, "agent.hooks.engine")
      if ok_he then pcall(he.run, "OnMemoryFlush", ctx) end
      io.write("\n\27[38;5;114m✅ Memory Flush concluído."
        .. " Processando sua mensagem...\27[0m\n\n")
    else
      io.write("\n\27[38;5;203m⚠️  Flush incompleto. "
        .. "Processando mesmo assim...\27[0m\n\n")
    end
    -- Sempre avança new_start e marca flush, mesmo em falha
    -- O FPM já tentou N vezes internamente via FlushLoop
    mf.marcar_flush(ctx.tokens)
    io.flush()
    return { flush_msgs_start = #ctx.msgs + 1 }
end

M.handle = handle
return M
