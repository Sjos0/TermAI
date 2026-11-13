-- main_loop.lua — Orquestrador do ciclo principal do agente (fachada).
-- Delega init de flush, idle/subagentes, handlers e router a módulos em agent/main_loop/.
-- Interface pública: M.run(ctx)
local ui             = require("ui")
local api            = require("agent.api")
local ag_loop        = require("agent.loop")
local harness_gancho = require("agent.harness")
local input_mod      = require("ui.input")
local restart_mod    = require("agent.restart")
local subagents      = require("tools.subagents")
local sub_block      = require("ui.subagent_block")

local timestamp    = require("agent.main_loop.timestamp")
local persistence  = require("agent.main_loop.persistence")
local compaction_h = require("agent.main_loop.compaction_handler")
local flush_h      = require("agent.main_loop.flush_handler")
local commands_r   = require("agent.main_loop.commands_router")
local overflow_h   = require("agent.main_loop.overflow_handler")
local flush_init   = require("agent.main_loop.flush_init")
local idle_poll    = require("agent.main_loop.idle_poll")

-- Mesmo prompt de ui/input.lua (o bloco reimprime o prompt ao redesenhar).
local PROMPT_TEXT = "\27[1m\27[38;5;39m❯\27[0m "

local function is_tty()
  return os.execute("test -t 0") == true
end

local M = {}

function M.run(ctx)
  local flush_msgs_start = flush_init.compute(ctx)

  while true do
    local comp = compaction_h.handle(ctx, flush_msgs_start)
    flush_msgs_start = comp.flush_msgs_start

    if restart_mod.check() then goto continue end

    local on_idle = idle_poll.make_on_idle(ctx, PROMPT_TEXT)
    sub_block.flush(ctx.agent_id, true, nil)
    local input, pasted_texts, raw_input, wake =
      input_mod.read(is_tty() and { on_idle = on_idle } or nil)
    if wake then
      input        = ""
      raw_input    = "[sistema] Os subagentes terminaram. Leia as mensagens do sistema e continue."
      pasted_texts = {}
    end
    if not input then
      local active = subagents.active_count(ctx)
      if active > 0 then
        require("tools.subagents.control").matar_todos(ctx)
        print(string.format(
          "\n%d subagente(s) encerrado(s) ao sair; o trabalho parcial fica salvo.", active))
      end
      print("\nSaindo..."); break
    end
    if input == "" and not wake then goto continue end

    local fl = flush_h.handle(ctx, raw_input, flush_msgs_start)
    flush_msgs_start = fl.flush_msgs_start

    local cmd = commands_r.route(input, ctx, flush_msgs_start)
    local display_input = cmd.input or input
    flush_msgs_start = cmd.flush_msgs_start or flush_msgs_start
    if cmd.action == "continue" then goto continue end
    if cmd.action == "break"    then break end

    ui.user_msg(display_input, pasted_texts)

    local ts            = timestamp.capture()
    local stamped_input = "[" .. ts .. "] " .. raw_input
    local msgs_before   = #ctx.msgs

    local resp, elapsed, _, is_overflow, stream_complete, reasoning =
      ag_loop.rodar(ctx, stamped_input, "user")

    local end_time = timestamp.to_hhmm(timestamp.capture())
    pcall(harness_gancho.depois_do_turno, { completo = stream_complete ~= false })

    if stream_complete == false and not is_overflow then
      io.write("\n\27[38;5;220m[WARN] Resposta incompleta — o stream foi cortado"
        .. " (timeout de " .. api.CURL_TIMEOUT .. "s).\27[0m\n")
      io.write("\27[38;5;245m   A resposta acima pode estar truncada."
        .. " Se necessário, peça para continuar.\27[0m\n\n")
      io.flush()
    end

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
    local before = persistence.adjust_before(ctx, msgs_before, stamped_input)
    persistence.save_exchange(
      ctx, before, reasoning, save_input, ctx.tokens_fresh, pasted_texts, stream_complete)
    ui.footer(ctx.tokens, ctx.active.context_window, elapsed, end_time)

    restart_mod.check()
    ::continue::
  end
end

return M
