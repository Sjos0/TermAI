package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/summarizer_orchestracao_spec.lua — #78: orquestração de summarizar entre tentativas.
-- Simula o curl pelo io.popen (lê o caminho de saída do próprio comando), o relógio e o sleep.
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local utils  = require("agent.api.utils")
local ui_mod = require("agent.api.summarizer.ui")
local runner = require("agent.api.summarizer.runner")

-- Caminhos temporários previsíveis; o teste confere se foram removidos.
-- Resolve o diretório ANTES dos stubs de os.execute abaixo (o helper usa mkdir).
local tmp_base = portable_tmp.dir()
local tmp_n = 0
utils.make_tmp_path = function() tmp_n = tmp_n + 1; return tmp_base .. "/termai_sum78_" .. tmp_n end

local clock, killed, sleeps = 0, {}, 0
ui_mod.get_wall_time = function() return clock end

local real_execute = os.execute
local real_popen   = io.popen
local curl_calls   = {}   -- caminhos de saída, na ordem das tentativas
local responder    = nil  -- função(n) -> conteúdo do arquivo de saída (ou nil = ainda não respondeu)

os.execute = function(cmd)
  local secs = cmd:match("^sleep ([%d%.]+)$")
  if secs then clock = clock + tonumber(secs); sleeps = sleeps + 1; return true end
  local pid = cmd:match("kill %-TERM (%d+)")
  if pid then killed[#killed + 1] = pid; return true end
  if cmd:find("kill %-KILL") then killed[#killed + 1] = "KILL"; return true end
  return true
end

io.popen = function(cmd)
  if cmd:find("kill -0", 1, true) then
    return { read = function() return "1\n" end, close = function() end }  -- morto
  end
  if cmd:find("curl", 1, true) then
    local out = nil
    for path in cmd:gmatch("> (%S+) 2>/dev/null") do out = path end   -- último = arquivo de saída
    curl_calls[#curl_calls + 1] = out
    local content = responder and responder(#curl_calls)
    if content and out then
      local f = assert(real_popen and io.open(out, "w")); f:write(content); f:close()
    end
    return { read = function() return "4242\n" end, close = function() end }
  end
  return real_popen(cmd)
end

local VALID = "## Objetivo\nConcluir a tarefa de teste com sucesso e registrar cada passo executado.\n"
  .. "## Progresso\nTodos os passos foram executados na ordem prevista e validados.\n"
  .. "## Decisão\nManter a abordagem atual porque cumpre o objetivo sem efeitos colaterais.\n"
  .. "## Estado\nTarefa concluída, sem pendências, pronta para o próximo passo."
local json = require("json")
local function ok_body(text) return json.encode({ choices = { { message = { content = text } } } }) end

local active = { model_id = "m", endpoint = "http://localhost/test", api_key = "k", context_window = 100000 }
local cfg = { agents = { defaults = { request = { timeout = 6, idle_timeout = 2, max_retries = 3 } } } }
local msgs = { { role = "user", content = "fazer algo" }, { role = "assistant", content = "feito" } }

local function reset()
  clock, killed, sleeps, curl_calls = 0, {}, 0, {}
end

-- (1) Tentativa 1 inválida (resposta curta); tentativa 2 válida: devolve a válida, usa 2 tentativas.
reset()
responder = function(n)
  if n == 1 then return ok_body("curto") end
  return ok_body(VALID)
end
local r1, e1 = runner.summarizar(active, cfg, msgs, nil, nil)
check(r1 ~= nil and r1:find("Objetivo", 1, true) ~= nil, "resposta inválida é re-tentada e a válida é devolvida")
check(#curl_calls == 2, "resposta inválida usa uma nova tentativa (usou " .. #curl_calls .. ")")
local leftover = false
for _, p in ipairs(curl_calls) do if io.open(p, "r") then leftover = true end end
check(not leftover, "temporários de saída de cada tentativa são removidos")

-- (2) Timeout em todas as tentativas: sem resposta, mata o curl e encerra com mensagem.
reset()
responder = function() return nil end
local r2, e2 = runner.summarizar(active, cfg, msgs, nil, nil)
check(r2 == nil and e2 ~= nil, "sem resposta em todas as tentativas: devolve nil e mensagem de falha")
check(#killed >= 1, "timeout mata o curl da tentativa antes de seguir (matou " .. #killed .. ")")
check(clock >= 6, "timeout respeita o prazo configurado (relógio " .. clock .. "s)")

-- (3) Erro HTTP (corpo com "error") é tratado como falha e re-tentado, sem esperar o prazo inteiro.
reset()
responder = function(n)
  if n == 1 then return '{"error":{"message":"rate limited"}}' end
  return ok_body(VALID)
end
local r3 = runner.summarizar(active, cfg, msgs, nil, nil)
check(r3 ~= nil, "erro HTTP na tentativa 1 é re-tentado e a 2 é aceita")
check(clock < 6, "erro HTTP não espera o prazo inteiro (relógio " .. clock .. "s)")

-- (4) Mensagens vazias: nada é chamado.
reset()
local r4, e4 = runner.summarizar(active, cfg, {}, nil, nil)
check(r4 == nil and e4 == "Nenhuma mensagem para resumir." and #curl_calls == 0,
  "sem mensagens não chama o curl")

-- restaura
os.execute = real_execute
io.popen = real_popen
ui_mod.get_wall_time = nil

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
