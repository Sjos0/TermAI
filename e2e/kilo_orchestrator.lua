-- e2e/kilo_orchestrator.lua — Orquestrador real: o modelo decide chamar sessions_spawn sozinho.
-- Não bloqueante no workflow: depende de o modelo gratuito usar ferramentas; o resultado é só reportado.
package.path = "./?.lua;./?/init.lua;" .. package.path
local json      = require("json")
local config    = require("config")
local log       = require("diag.log")
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
require("e2e.common").ensure_kilo()

local MODEL   = "kilo/kilo-auto/free"
local out_dir = os.getenv("E2E_OUT") or "/tmp/termai-e2e"
local home    = os.getenv("HOME")
os.execute(string.format("mkdir -p '%s'", out_dir))

config.set("agents.defaults.model.primary", MODEL)
config.set("agents.defaults.subagents.maxConcurrent", 2)
-- Probe headless: Read pré-aprovado só para testar a capacidade de chamar a tool,
-- sem diálogo de permissão (que em CI sempre seria negado).
config.set("hooks.permissions.Read", "always")

local prompt = "Use a ferramenta sessions_spawn para criar um subagente com a tarefa: "
  .. "'Responda apenas com a palavra ORQ_SUB_OK.' Depois de criar o subagente, responda somente: ORQUESTRADOR_OK"
local pf = io.open(out_dir .. "/orch_prompt.txt", "w"); pf:write(prompt); pf:close()

local t0 = os.time()
local function log_lines() return #log.tail(1000000) end
local lines_before = log_lines()
local cmd = string.format("lua5.4 '%s/TermAI/main.lua' run --prompt-file '%s/orch_prompt.txt' --max-iter 6 > '%s/orchestrator.log' 2>&1",
  home, out_dir, out_dir)
local _, _, code = os.execute(cmd)
local orch_ok_text = false
local f = io.open(out_dir .. "/orchestrator.log", "r")
local orch_out = f and f:read("*a") or ""
if f then f:close() end
local orch_echoless = orch_out:gsub(prompt, "")  -- o run pode ecoar o prompt, que contém a palavra-chave
orch_ok_text = orch_echoless:find("ORQUESTRADOR_OK", 1, true) ~= nil

-- Runs criados pelo orquestrador desde o início deste teste.
local spawned = {}
for _, r in ipairs(registry.list()) do
  if (r.created_at or 0) >= t0 then spawned[#spawned + 1] = r end
end

local cfg = config.load()
local deadline = os.time() + 600
local all_done = #spawned > 0
while #spawned > 0 and os.time() < deadline do
  scheduler.tick(cfg)
  all_done = true
  for _, r in ipairs(spawned) do
    local cur = registry.load(r.runId)
    if not cur or not scheduler.is_terminal(cur) then all_done = false end
  end
  if all_done then break end
  os.execute("sleep 3")
end

local sub_ok = false
local details = {}
for _, r in ipairs(spawned) do
  local cur = registry.load(r.runId) or r
  local res = registry.read_result(r.runId) or ""
  details[#details + 1] = { run_id = r.runId, status = cur.status, result_head = res:sub(1, 80) }
  if cur.status == "completed" and res:upper():find("ORQ_SUB_OK", 1, true) then sub_ok = true end
end

-- Diagnóstico: o modelo chama QUALQUER tool? (cabeçalho "⬤ <Nome> |" aparece no log)
local tool_calls_seen = 0
for _ in orch_out:gmatch("%u[%a_]+ | ") do tool_calls_seen = tool_calls_seen + 1 end
local probe_out = ""
local lines_mid = log_lines()
local t_probe = os.time()
local pp = io.open(out_dir .. "/probe_prompt.txt", "w")
pp:write("Use a ferramenta Read para ler o arquivo README.md e responda somente: PROBE_OK")
pp:close()
local pc = string.format("lua5.4 '%s/TermAI/main.lua' run --prompt-file '%s/probe_prompt.txt' --max-iter 4 > '%s/probe.log' 2>&1",
  home, out_dir, out_dir)
os.execute(pc)
local pf2 = io.open(out_dir .. "/probe.log", "r")
probe_out = pf2 and pf2:read("*a") or ""
if pf2 then pf2:close() end
local probe_tool = probe_out:find("Read |", 1, true) ~= nil
-- Sinais de erro de rede/limite no log (ex.: 429 do gateway, tentativas esgotadas).
local error_signals = {}
for _, k in ipairs({ "429", "Sem resposta", "Tentativa 10/10", "ERRO", "rate limit" }) do
  if (orch_out .. probe_out):find(k, 1, true) then error_signals[#error_signals + 1] = k end
end

-- Turnos do modelo do ORQUESTRADOR (entre t0 e a sonda): quantos tiveram tool call, e quais.
local tool_turns, total_turns, tool_names = 0, 0, {}
-- Janela por linhas do log (não por relógio): turnos do orquestrador são as linhas entre o início e a sonda.
local all_turns = 0
local all_lines = log.tail(1000000)
for i, line in ipairs(all_lines) do
  local ok_ev, ev = pcall(json.decode, line)
  if ok_ev and type(ev) == "table" and ev.event == "model_turn" and i > lines_before then all_turns = all_turns + 1 end
  if ok_ev and type(ev) == "table" and ev.event == "model_turn" and not ev.is_subagent
     and i > lines_before and i <= lines_mid then
    total_turns = total_turns + 1
    if (ev.tool_calls or 0) > 0 then
      tool_turns = tool_turns + 1
      tool_names[#tool_names + 1] = tostring(ev.tool_name)
    end
  end
end

local report = { check = "orquestrador", model = MODEL, exit_code = code,
  model_turns = total_turns, model_turns_with_tools = tool_turns, tool_names = tool_names,
  model_turns_any = all_turns, run_exit = code, run_output_has_result = orch_out:find("TERMAI_RUN", 1, true) ~= nil,
  tool_headers_in_orchestrator = tool_calls_seen, probe_read_tool_called = probe_tool,
  error_signals = error_signals,
  probe_answer_ok = probe_out:find("PROBE_OK", 1, true) ~= nil,
  orchestrator_answer_ok = orch_ok_text, spawned = #spawned, sub_completed_ok = sub_ok,
  passed = orch_ok_text and sub_ok, runs = details, output_head = orch_out:sub(1, 300) }
f = io.open(out_dir .. "/orchestrator.json", "w"); f:write(json.encode(report)); f:close()
log.info("e2e_orchestrator", { passed = report.passed, spawned = #spawned, answer_ok = orch_ok_text })
print(report.passed and "ORQUESTRADOR OK" or "ORQUESTRADOR NÃO CONFIRMADO (ver orchestrator.json)")
os.exit(report.passed and 0 or 1)
