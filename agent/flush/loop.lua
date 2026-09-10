-- agent/flush/loop.lua — FlushLoop (FPM): loop ReAct isolado do Memory Flush.
-- NÃO chama ag_loop.rodar: evita ui.ai_msg_stream, _mem.search, boot injection.
-- Reutiliza o spinner adaptativo do loop principal via ui.start_thinking / update_label.
local api           = require("agent.api")
local tool_runner   = require("agent.loop.tool_runner")
local ui            = require("ui")
local gate_detector = require("agent.flush.gate_detector")
local checklist     = require("agent.flush.checklist")

local M = {}

--- Executa o loop ReAct do flush sobre um contexto isolado já montado.
-- @param flush_ctx table Sandbox com msgs, flush_state, MAX_ITER, cfg, active
-- @param flush_prompt string Prompt inicial do protocolo
-- @return boolean true se completou (done), false se overflow ou MAX_ITER
function M.run_loop(flush_ctx, flush_prompt)
  local iter = 0
  local cur_text = flush_prompt
  local cur_role = "user"
  local limit = flush_ctx.MAX_ITER or 10

  ui.update_label() -- transição Injetando -> Requisitando (contexto já montado)
  local spinner_started = true -- spinner já rodando (fase acima)

  while iter < limit do
    iter = iter + 1
    if not spinner_started then ui.start_thinking() end
    spinner_started = false

    -- Injeta o checklist no prompt (FPM: ChecklistRenderer)
    local status = checklist.render_checklist(flush_ctx.flush_state)
    local prompt_com_checklist = nil

    if cur_text then
      prompt_com_checklist = cur_text .. "\n\n" .. status
    else
      -- Se cur_text é nil (iterações subsequentes), injeta ou substitui o checklist na última
      -- mensagem de histórico, independente de role (Mitiga Problemas 1 e 2 do Ameno)
      local last_msg = flush_ctx.msgs[#flush_ctx.msgs]
      if last_msg then
        if last_msg.content:match("<FLUSH_STATUS>") then
          last_msg.content = last_msg.content:gsub("<FLUSH_STATUS>.-</FLUSH_STATUS>", status)
        else
          last_msg.content = last_msg.content .. "\n\n" .. status
        end
      end
    end

    -- Chama a API — o streaming aciona ui.stream_* internamente (mesmo
    -- pipeline usado pelo loop principal), o que acende o spinner.
    local resp, is_overflow, _, _, tool_calls =
      api.pensar_stream(flush_ctx, prompt_com_checklist, cur_role)
    ui.stop_thinking()

    if is_overflow then
      return false  -- overflow do provedor = desiste graciosamente
    end

    -- Processa tool_calls (caminho nativo JSON)
    if tool_calls and #tool_calls > 0 then
      tool_runner.run_batch(flush_ctx, tool_calls)

      -- Detecta gates baseado nas tool_calls executadas
      -- tool_results não estão disponíveis diretamente; detect_gates
      -- usa o resp para FLUSH_DONE e as tool_calls originais
      gate_detector.detect_gates(tool_calls, resp or "", flush_ctx.flush_state)

      cur_text = nil
      cur_role = nil

      if flush_ctx.flush_state.done then
        return true
      end
    else
      -- Resposta sem tool_calls: verifica FLUSH_DONE no texto
      gate_detector.detect_gates({}, resp or "", flush_ctx.flush_state)

      if flush_ctx.flush_state.done then
        return true
      end
    end
  end

  -- MAX_ITER estourado sem completar = desiste graciosamente
  return false
end

return M
