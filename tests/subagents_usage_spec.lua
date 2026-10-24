package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagents_usage_spec.lua — consumo de tokens por run (acumulado por chamada) e cartão.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local usage = require("agent.api.usage")
local tokens = require("agent.api.request_stream.tokens")
local card = require("tools.subagents.card")

-- (1) Soma por chamada; o total é o que foi cobrado (reenvio do contexto conta a cada chamada).
local acc = nil
acc = usage.add(acc, { prompt_tokens = 100, completion_tokens = 20, total_tokens = 120 })
acc = usage.add(acc, { prompt_tokens = 150, completion_tokens = 30, total_tokens = 180 })
acc = usage.add(acc, { prompt_tokens = 200, completion_tokens = 10 })   -- sem total: prompt + completion
check(acc.prompt == 450 and acc.completion == 60, "acumula entrada e saída por chamada")
check(acc.total == 510 and acc.calls == 3, "total: 120 + 180 + 210 (terceira chamada cai para prompt+completion)")
check(usage.add(acc, nil) == acc, "usage ausente não altera o acumulador")
check(usage.add(acc, "lixo") == acc, "usage de tipo errado é ignorado")

-- (2) O caminho de streaming acumula em ctx.usage_acc, mesmo sem total_tokens no chunk.
local ctx = { msgs = {}, tokens = 0 }
tokens.process_tokens(ctx, { usage = { prompt_tokens = 50, completion_tokens = 5, total_tokens = 55 } })
tokens.process_tokens(ctx, { usage = { prompt_tokens = 60, completion_tokens = 6, total_tokens = 66 } })
tokens.process_tokens(ctx, { choices = {} })   -- chunk sem usage não conta
check(ctx.usage_acc and ctx.usage_acc.calls == 2 and ctx.usage_acc.total == 121,
  "streaming: acumula dois usages e ignora chunk sem usage")

-- (3) Cartão: com uso, mostra entrada, saída, total e chamadas; sem uso, declara.
local with = card.build({ runId = "sub-u1", status = "completed", task = "t", agentId = "main",
  parent_agent = "main", cleanup = "retain", usage = { prompt = 450, completion = 60, total = 360, calls = 3 } }, {})
check(with:find("entrada 450", 1, true) and with:find("saída 60", 1, true) and with:find("total 360", 1, true),
  "cartão: mostra entrada, saída e total")
check(with:find("3 chamadas", 1, true) ~= nil, "cartão: mostra o número de chamadas")
local without = card.build({ runId = "sub-u2", status = "completed", task = "t", agentId = "main",
  parent_agent = "main", cleanup = "retain" }, {})
check(without:find("não registrados", 1, true) ~= nil, "cartão: sem uso declara que não foi registrado")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
