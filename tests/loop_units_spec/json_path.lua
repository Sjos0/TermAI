-- tests/loop_units_spec/json_path.lua — parte do spec de agent/loop (ver tests/loop_units_spec.lua).
local harness = require("tests.helpers.harness")
local D = require("tests.loop_units_spec.dobles")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  sec("json_path.handle")

  package.loaded["agent.loop.json_path"] = nil
  local jp = require("agent.loop.json_path")

  local function fresh_ctx(flags)
    flags = flags or {}
    return {
      tool_cancelled = flags.tool_cancelled,
      prev_command_cancelled = flags.prev_command_cancelled,
    }
  end

  D.reset_ui_log()
  D.batch_log = {}
  local ctx = fresh_ctx()
  local r = jp.handle(ctx, "vou executar", { { name = "Exec" } }, true, 1.5)
  T("json continue: action=continue", r.action == "continue")
  T("json continue: iter_delta=1", r.iter_delta == 1)
  T("json continue: cur_text nil", r.cur_text == nil)
  T("json continue: cur_role nil", r.cur_role == nil)
  T("json continue: last_reasoning vazio", r.last_reasoning == "")
  T("json continue: streamou texto",
    #D.ui_log == 1 and D.ui_log[1].op == "ai_msg_stream" and D.ui_log[1].text == "vou executar")
  T("json continue: run_batch chamado", #D.batch_log == 1)

  D.reset_ui_log()
  D.batch_log = {}
  r = jp.handle(fresh_ctx(), "[FLUSH_DONE]", { { name = "X" } }, true, 0.2)
  T("json FLUSH_DONE puro: action=return", r.action == "return")
  T("json FLUSH_DONE puro: flush_done=true", r.flush_done == true)
  T("json FLUSH_DONE puro: não streama vazio", #D.ui_log == 0)
  T("json FLUSH_DONE puro: is_overflow=false", r.is_overflow == false)
  T("json FLUSH_DONE puro: propaga elapsed", r.elapsed == 0.2)
  T("json FLUSH_DONE puro: propaga stream_complete", r.stream_complete == true)

  D.reset_ui_log()
  r = jp.handle(fresh_ctx(), "arquivo salvo [FLUSH_DONE]", { { name = "Write" } }, false, 3)
  T("json FLUSH_DONE+texto: return+flush_done", r.action == "return" and r.flush_done == true)
  T("json FLUSH_DONE+texto: streamou sem tag",
    #D.ui_log == 1 and D.ui_log[1].text:find("FLUSH_DONE") == nil and D.ui_log[1].text:find("arquivo salvo") ~= nil)
  T("json FLUSH_DONE+texto: stream_complete propagado", r.stream_complete == false)

  package.loaded["agent.loop.tool_runner"].run_batch = function(c, tc)
    D.batch_log[#D.batch_log + 1] = { ctx = c, tool_calls = tc }
    c.tool_cancelled = true
  end
  package.loaded["agent.loop.json_path"] = nil
  jp = require("agent.loop.json_path")

  ctx = fresh_ctx()
  r = jp.handle(ctx, "rodando", { { name = "Exec" } }, true, 9)
  T("json cancel: action=return", r.action == "return")
  T("json cancel: flush_done=false", r.flush_done == false)
  T("json cancel: tool_cancelled consumido", ctx.tool_cancelled == nil)
  T("json cancel: prev_command_cancelled=true", ctx.prev_command_cancelled == true)
  T("json cancel: resp original preservado", r.resp == "rodando")
  T("json cancel: last_reasoning vazio", r.last_reasoning == "")

  -- Trava do Caçador (PR #40): cancel com last_reasoning outer NÃO-vazio
  ctx = fresh_ctx()
  r = jp.handle(ctx, "rodando", { { name = "Exec" } }, true, 9, "raciocínio preservado")
  T("json cancel: last_reasoning outer não-vazio propagado",
    r.action == "return"
    and r.last_reasoning == "raciocínio preservado",
    "esperado propagar outer; got: " .. tostring(r.last_reasoning))

  ctx = fresh_ctx()
  r = jp.handle(ctx, "done [FLUSH_DONE]", { { name = "X" } }, true, 1)
  T("json cancel>FLUSH_DONE: flush_done=false (cancel vence)", r.flush_done == false)
  T("json cancel>FLUSH_DONE: action=return", r.action == "return")

  package.loaded["agent.loop.tool_runner"].run_batch = function(c, tc)
    D.batch_log[#D.batch_log + 1] = { ctx = c, tool_calls = tc }
  end
  package.loaded["agent.loop.json_path"] = nil
  jp = require("agent.loop.json_path")

  r = jp.handle(fresh_ctx(), "ok", { { name = "A" } }, true, 0)
  T("json continue contrato: sem flush_done", r.flush_done == nil)
  T("json continue contrato: sem is_overflow", r.is_overflow == nil)

end

return M
