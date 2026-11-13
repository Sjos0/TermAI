-- tests/main_loop_idle_poll_spec.lua — callback on_idle extraído (Issue #363 / PR #364).
-- Origem: refactor/363-main-loop-srp — idle_poll.make_on_idle.
-- Objetivo: trava de regressão para o throttle de 2s do scheduler.tick,
--           a chamada a sub_block.flush e o retorno buffer_empty and has_pending.
--
-- "E se isso mudar?": alteração no intervalo de tick, na ordem das
-- chamadas, no contrato do callback ou no short-circuit do return
-- deve falhar aqui antes de afetar o loop principal.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then
    print("OK:   " .. msg)
  else
    failures = failures + 1
    print("FAIL: " .. msg)
  end
end

-- --- Dublês ---
local tick_calls = 0
local tick_cfg_seen = nil
local flush_calls = {}
local has_pending_result = false
local fake_time = 1000

package.loaded["tools.subagents.scheduler"] = {
  tick = function(cfg)
    tick_calls = tick_calls + 1
    tick_cfg_seen = cfg
  end,
}
package.loaded["tools.subagents"] = {
  has_pending = function(ctx)
    return has_pending_result
  end,
}
package.loaded["ui.subagent_block"] = {
  flush = function(agent_id, buffer_empty, prompt_text)
    flush_calls[#flush_calls + 1] = {
      agent_id = agent_id,
      buffer_empty = buffer_empty,
      prompt_text = prompt_text,
    }
  end,
}

-- Controla os.time para o throttle de 2s
local _os_time = os.time
os.time = function() return fake_time end

package.loaded["agent.main_loop.idle_poll"] = nil
local idle_poll = require("agent.main_loop.idle_poll")

local ctx = { agent_id = "main", cfg = { agents = {} } }
local PROMPT = "❯ "

-- 1) make_on_idle devolve função
local on_idle = idle_poll.make_on_idle(ctx, PROMPT)
T(type(on_idle) == "function", "make_on_idle retorna function")

-- 2) primeira chamada: tick + flush + return false (buffer cheio ou sem pending)
tick_calls = 0
flush_calls = {}
has_pending_result = false
local ret = on_idle(false)
T(tick_calls == 1, "1ª chamada (t=1000): scheduler.tick executa")
T(tick_cfg_seen == ctx.cfg, "tick recebe ctx.cfg")
T(#flush_calls == 1, "1ª chamada: sub_block.flush uma vez")
T(flush_calls[1].agent_id == "main" and flush_calls[1].buffer_empty == false
    and flush_calls[1].prompt_text == PROMPT,
  "flush recebe agent_id, buffer_empty=false, prompt")
T(ret == false, "return = false quando buffer_empty=false")

-- 3) segunda chamada no mesmo segundo: não re-ticky, mas flush de novo
flush_calls = {}
ret = on_idle(true)
T(tick_calls == 1, "2ª chamada (mesmo t): tick NÃO reexecuta (throttle)")
T(#flush_calls == 1, "2ª chamada: flush ainda é chamado")
T(flush_calls[1].buffer_empty == true, "flush recebe buffer_empty=true")
T(ret == false, "return = false (has_pending=false) mesmo com buffer vazio")

-- 4) avança tempo < 2s: ainda sem tick
fake_time = 1001
flush_calls = {}
on_idle(true)
T(tick_calls == 1, "t+1s: tick continua bloqueado pelo throttle de 2s")

-- 5) avança >= 2s: tick de novo
fake_time = 1002
flush_calls = {}
ret = on_idle(true)
T(tick_calls == 2, "t+2s: scheduler.tick executa de novo")
T(#flush_calls == 1, "t+2s: flush chamado")

-- 6) return true somente quando buffer_empty e has_pending
has_pending_result = true
ret = on_idle(true)
T(ret == true, "return = true quando buffer_empty e has_pending")

has_pending_result = true
ret = on_idle(false)
T(ret == false, "return = false quando has_pending mas buffer NÃO vazio")

-- 7) tick que lança erro não derruba o callback (pcall)
package.loaded["tools.subagents.scheduler"] = {
  tick = function()
    error("tick boom")
  end,
}
package.loaded["agent.main_loop.idle_poll"] = nil
-- reinicia módulo para pegar o novo double (e novo last_tick=0)
idle_poll = require("agent.main_loop.idle_poll")
fake_time = 2000
local on_idle2 = idle_poll.make_on_idle(ctx, PROMPT)
local ok_call = pcall(on_idle2, true)
T(ok_call == true, "erro em scheduler.tick é engolido por pcall; callback não propaga")

-- restaura
os.time = _os_time

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
