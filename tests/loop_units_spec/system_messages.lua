-- tests/loop_units_spec/system_messages.lua — parte do spec de agent/loop (ver tests/loop_units_spec.lua).
local harness = require("tests.helpers.harness")
local D = require("tests.loop_units_spec.dobles")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  local function reload_system_messages()
    package.loaded["agent.loop.system_messages"] = nil
    package.loaded["tools.memory"] = nil
    return require("agent.loop.system_messages")
  end

  sec("system_messages.prepare_user_turn — role / no-op")

  D.mem_state.available = false
  local sm = reload_system_messages()

  local ctx_noop = { msgs = { { role = "system" } }, last_tool_sig = "x" }
  local out, spin = sm.prepare_user_turn(ctx_noop, "texto", "assistant")
  T("role != user → texto intacto", out == "texto")
  T("role != user → spinner false", spin == false)
  T("role != user → last_tool_sig NÃO limpo", ctx_noop.last_tool_sig == "x")

  sec("system_messages — boot login vs restart")

  D.mem_state.available = false
  sm = reload_system_messages()
  local ctx_login = { msgs = { { role = "system" } }, last_tool_sig = "sig" }
  out, spin = sm.prepare_user_turn(ctx_login, "oi", "user")
  T("login: last_tool_sig limpo", ctx_login.last_tool_sig == nil)
  T("login: injeta User has joined",
    type(out) == "string" and out:find("User has joined the session") ~= nil)
  T("login: preserva texto do user", out:find("oi") ~= nil)
  T("login: sem memória → spinner false", spin == false)

  out = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "segundo", "user")
  T("segundo turno: sem nova system message de boot",
    out:find("SYSTEM MESSAGE: User has joined") == nil
    and out:find("System has restarted") == nil)
  T("segundo turno: texto puro", out == "segundo")

  sm = reload_system_messages()
  local ctx_restart = {
    msgs = {
      { role = "system" },
      { role = "user" },
      { role = "assistant" },
    },
  }
  out = sm.prepare_user_turn(ctx_restart, "continua", "user")
  T("restart: injeta System has restarted",
    out:find("System has restarted") ~= nil)
  T("restart: preserva texto", out:find("continua") ~= nil)

  sec("system_messages — cancelamento prévio")

  sm = reload_system_messages()
  sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")

  local ctx_cancel = {
    msgs = { { role = "system" } },
    prev_command_cancelled = true,
  }
  out = sm.prepare_user_turn(ctx_cancel, "novo plano", "user")
  T("cancel: injeta CANCELLED",
    out:find("CANCELLED by the user") ~= nil)
  T("cancel: flag consumida (nil)", ctx_cancel.prev_command_cancelled == nil)
  T("cancel: preserva texto do user", out:find("novo plano") ~= nil)

  sm = reload_system_messages()
  local ctx_both = {
    msgs = { { role = "system" } },
    prev_command_cancelled = true,
  }
  out = sm.prepare_user_turn(ctx_both, "hi", "user")
  T("boot+cancel: ambas injeções presentes",
    out:find("User has joined") ~= nil and out:find("CANCELLED") ~= nil)

  sec("system_messages — injeção de memória")

  D.mem_state.available = true
  D.mem_state.should_error = false
  D.mem_state.result = "fato importante da sessão"
  sm = reload_system_messages()
  sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
  D.reset_ui_log()
  out, spin = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "pergunta longa o bastante", "user")
  T("mem hit: spinner true", spin == true)
  T("mem hit: prefixo MEMÓRIA RELEVANTE",
    out:find("MEMÓRIA RELEVANTE") ~= nil)
  T("mem hit: conteúdo injetado", out:find("fato importante") ~= nil)
  T("mem hit: pergunta preservada", out:find("pergunta longa") ~= nil)
  T("mem hit: start_thinking Injetando",
    #D.ui_log >= 1 and D.ui_log[1].op == "start_thinking" and D.ui_log[1].label == "Injetando")
  T("mem hit: update_label chamado",
    (function()
      for _, e in ipairs(D.ui_log) do if e.op == "update_label" then return true end end
      return false
    end)())

  local reject_prefixes = { "[FAIL] erro", "[EMPTY] vazio", "[SEARCH] Nenhuma memória" }
  for _, prefix in ipairs(reject_prefixes) do
    D.mem_state.result = prefix .. " resto"
    sm = reload_system_messages()
    sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
    out = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "pergunta longa o bastante", "user")
    T("mem rejeita prefixo '" .. (prefix:match("^(%[%u+%])") or prefix) .. "...'",
      out:find("MEMÓRIA RELEVANTE") == nil)
  end

  D.mem_state.should_error = true
  D.mem_state.result = "ignorar"
  sm = reload_system_messages()
  sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
  out, spin = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "pergunta longa o bastante", "user")
  T("mem search error: spinner ainda true (start_thinking rodou)", spin == true)
  T("mem search error: sem injeção", out:find("MEMÓRIA RELEVANTE") == nil)

  D.mem_state.should_error = false
  D.mem_state.result = "não deve aparecer"
  sm = reload_system_messages()
  sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
  out, spin = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "ab", "user")
  T("mem cur_text len<=2: sem busca/spinner", spin == false and out == "ab")

end

return M
