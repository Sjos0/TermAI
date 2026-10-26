-- tests/flush_api_error_abort_spec.lua
-- Garante que o Memory Flush NÃO reinicia o ciclo de retries da API
-- quando pensar_stream devolve "[ERRO] ...".
--
-- Sintoma original: após 5/5 o contador voltava para 1/5 e o loop
-- chamava a API de novo indefinidamente dentro do while do flush.

package.path = "./?.lua;./?/init.lua;" .. package.path

local calls = 0
local fake_resp = "[ERRO] Falha apos 5 tentativas - Sem resposta do servidor"

package.preload["agent.api"] = function()
  return {
    pensar_stream = function(_ctx, _txt, _role)
      calls = calls + 1
      -- Simula o contrato real de falha terminal (sem overflow, sem tool_calls)
      return fake_resp, false, nil, "", nil
    end,
  }
end

package.preload["agent.loop.tool_runner"] = function()
  return {
    run_batch = function()
      error("tool_runner não deveria ser chamado em falha de API")
    end,
  }
end

package.preload["ui"] = function()
  return {
    update_label = function() end,
    start_thinking = function() end,
    stop_thinking = function() return 0 end,
  }
end

-- checklist e gate_detector reais (sem dependência de API)
local ok_loop, flush_loop = pcall(require, "agent.flush.loop")
assert(ok_loop, "falha ao carregar agent.flush.loop: " .. tostring(flush_loop))

local flush_ctx = {
  cfg = {},
  active = { endpoint = "http://test", api_key = "x", ref = "test" },
  tokens = 0,
  MAX_ITER = 10,
  msgs = {
    { role = "system", content = "sys" },
    { role = "user", content = "ctx" },
  },
  flush_state = {
    exec = false, read = false, edit = false, done = false,
    reset = function() end,
  },
}

local done = flush_loop.run_loop(flush_ctx, "prompt de flush de teste")

assert(done == false, "deveria abortar com false em erro de API")
assert(calls == 1,
  "pensar_stream deveria ser chamado exatamente 1 vez, foi " .. tostring(calls)
  .. " (loop reiniciando retries = bug)")

print("PASS  flush_api_error_abort_spec: 1 chamada API + abort em [ERRO]")
