-- agent/flush.lua — Fachada do Memory Flush em contexto isolado.
-- Refatorado a partir do monólito de 212 linhas (Issue #28).
-- Flush Protocol Monitor (FPM) — supervisor de estado do protocolo de Memory Flush.
-- ARQUITETURA: Recebe apenas as mensagens NOVAS desde o último flush,
-- não toda a conversa. Isso reduz alucinações e melhora a precisão do resumo.
-- O agente de flush NÃO TEM ACESSO ao histórico completo da sessão principal.
--
-- Apenas importa submódulos e orquestra M.run. Zero lógica de protocolo aqui.
local ui             = require("ui")
local format_context = require("agent.flush.format_context")
local flush_loop     = require("agent.flush.loop")

local M = {}

--- Executa o flush em contexto isolado (Sandbox).
-- ctx: contexto principal (para active/cfg — não é modificado!)
-- new_msgs: apenas as mensagens recentes
-- flush_prompt: prompt do protocolo (vindo de memoryflush)
-- @return boolean true se o protocolo completou (done), false caso contrário
function M.run(ctx, new_msgs, flush_prompt)
  -- Spinner adaptativo: reaproveita a MESMA state machine do ReAct loop
  -- principal (ui/spinner.lua), sem reimplementar nada. "Injetando" cobre
  -- a montagem do contexto isolado do flush — equivalente, em custo e
  -- posição no fluxo, à injeção de memória do loop normal (agent/loop.lua).
  ui.start_thinking("Injetando")
  local context_text = format_context.format_context(new_msgs)

  -- System prompt mínimo: apenas tools + regra de confidencialidade
  -- Sem SOUL.md, IDENTITY.md etc. — o MemoryFlush não tem personalidade, é um operário.
  local system = table.concat({
    "Você é o MemoryFlush, um processo interno do TermAI.",
    "Sua única função é arquivar memórias. Siga o protocolo rigorosamente.",
  }, "\n")

  -- Criação da Sandbox (Contexto isolado)
  local flush_ctx = {
    cfg      = ctx.cfg,
    active   = ctx.active,
    tokens   = 0,
    MAX_ITER = 10,  -- limite para o flush completar todos os passos sem loop infinito
    msgs     = {
      { role = "system",    content = system },
      { role = "user",      content = "[CONTEXTO DO CICLO ATUAL]\n\n" .. context_text },
      { role = "assistant", content = "Contexto recebido. Iniciando protocolo de flush." },
    },
    flush_state = {
      exec = false,
      read = false,
      edit = false,
      done = false,
    },
  }

  function flush_ctx.flush_state.reset()
    flush_ctx.flush_state.exec = false
    flush_ctx.flush_state.read = false
    flush_ctx.flush_state.edit = false
    flush_ctx.flush_state.done = false
  end

  return flush_loop.run_loop(flush_ctx, flush_prompt)
end

return M
