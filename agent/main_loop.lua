-- main_loop.lua — Fachada + Loop principal do agente.
-- Integra State Condensation (OpenHands-style) com resiliência total.
-- flush_msgs_start marca o início das mensagens NOVAS desta execução.
-- Tudo antes deste índice é histórico já arquivado — o flush não o processa.
-- Interface pública: M.run(ctx)
local ui          = require("ui")
local api         = require("agent.api")
local ag_loop     = require("agent.loop")
local input_mod   = require("ui.input")
local restart_mod = require("agent.restart")
local session     = require("session")

local timestamp    = require("agent.main_loop.timestamp")
local persistence  = require("agent.main_loop.persistence")
local compaction_h = require("agent.main_loop.compaction_handler")
local flush_h      = require("agent.main_loop.flush_handler")
local commands_r   = require("agent.main_loop.commands_router")
local overflow_h   = require("agent.main_loop.overflow_handler")

local M = {}

function M.run(ctx)
  -- Lógica de inicialização do Harness Inteligente (com proteção contra sessões legadas)
  local saved_idx = session.get_flush_index and session.get_flush_index() or nil
  local flush_msgs_start

  if saved_idx then
    -- Sessão possui estado de flush salvo (Continua de onde parou)
    flush_msgs_start = saved_idx + 1
  elseif #ctx.msgs > 0 then
    -- Sessão legado (tem mensagens, mas nunca salvou índice).
    -- Trava contra "Sandbox Blowout": Pega apenas as últimas 15 mensagens para não travar a API.
    flush_msgs_start = math.max(1, #ctx.msgs - 15)
  else
    -- Sessão nova e vazia
    flush_msgs_start = #ctx.msgs + 1
  end

  while true do

    -- 1. AUTO-COMPACTION (State Condensation)
    local comp = compaction_h.handle(ctx, flush_msgs_start)
    flush_msgs_start = comp.flush_msgs_start

    if restart_mod.check() then goto continue end

    -- 2. LER INPUT DO USUÁRIO
    local input, pasted_texts, raw_input = input_mod.read()
    if not input then print("\nSaindo..."); break end
    if input == "" then goto continue end

    -- 3. MEMORY FLUSH PRÉ-INPUT (Contexto Isolado com conteúdo BRUTO)
    local fl = flush_h.handle(ctx, raw_input, flush_msgs_start)
    flush_msgs_start = fl.flush_msgs_start

    -- 4. ROTEAMENTO DE COMANDOS (com a versão placeholder)
    local cmd = commands_r.route(input, ctx, flush_msgs_start)
    local display_input = cmd.input or input
    flush_msgs_start = cmd.flush_msgs_start or flush_msgs_start
    if cmd.action == "continue" then goto continue end
    if cmd.action == "break"    then break end

    -- 5. INPUT NORMAL (Imprime na TUI a versão compacta com metadados)
    ui.user_msg(display_input, pasted_texts)

    local ts            = timestamp.capture()
    local stamped_input = "[" .. ts .. "] " .. raw_input
    local msgs_before   = #ctx.msgs

    local resp, elapsed, _, is_overflow, stream_complete, reasoning =
      ag_loop.rodar(ctx, stamped_input, "user")

    local end_time = timestamp.to_hhmm(timestamp.capture())

    -- Aviso se o stream foi cortado por timeout (resposta incompleta)
    if stream_complete == false and not is_overflow then
      io.write("\n\27[38;5;220m⚠️  Resposta incompleta — o stream foi cortado"
        .. " (timeout de " .. api.CURL_TIMEOUT .. "s).\27[0m\n")
      io.write("\27[38;5;245m   A resposta acima pode estar truncada."
        .. " Se necessário, peça para continuar.\27[0m\n\n")
      io.flush()
    end

    -- 6. RECUPERAÇÃO DE OVERFLOW COM RESILIÊNCIA
    if is_overflow then
      local ov = overflow_h.handle(ctx, stamped_input, msgs_before, flush_msgs_start)
      msgs_before      = ov.msgs_before
      flush_msgs_start = ov.flush_msgs_start
      resp             = ov.resp
      elapsed          = ov.elapsed
      is_overflow      = ov.is_overflow
      stream_complete  = ov.stream_complete
      reasoning        = ov.reasoning
      end_time         = ov.end_time
    end

      local save_input = "[" .. ts .. "] " .. input
      persistence.save_exchange(ctx, msgs_before, reasoning, save_input, ctx.tokens_fresh, pasted_texts)
    ui.footer(ctx.tokens, ctx.active.context_window, elapsed, end_time)

    -- Verifica restart imediato pós-resposta (ex: agente usou a tool restart nativa)
    -- Sem isso, o restart só ocorre no próximo ciclo, após o usuário digitar algo.
    restart_mod.check()
    ::continue::
  end
end

return M
