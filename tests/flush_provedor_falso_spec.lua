-- tests/flush_provedor_falso_spec.lua
-- Issue #326 — reprodução do Memory Flush com PROVEDOR FALSO local (loopback,
-- sem rede externa e sem chave de API).
--
-- Roda o caminho REAL: agent.flush.run -> format_context -> flush.loop ->
-- agent.api.pensar_stream -> curl -> servidor falso (tests/fake_provider_326.py).
-- Apenas `ui` e `agent.loop.tool_runner` entram como dublês: o dublê do
-- tool_runner chama o `Read` REAL do registry de `tools` para produzir o
-- resultado da leitura (nada de resultado inventado).

package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local falhas = 0
local function check(cond, msg)
  if cond then
    print("ok   - " .. msg)
  else
    print("FAIL - " .. msg)
    falhas = falhas + 1
  end
end

local TMP    = os.getenv("TMPDIR") or "/tmp"
local PY     = "python3"
local SCRIPT = "tests/fake_provider_326.py"

-- O CI do projeto já usa python3 (teste de PTY). Sem ele, não há como subir o
-- provedor falso: pular sem marcar falha apenas quando o binário não existe.
local ok_py = os.execute(PY .. " -c '' >/dev/null 2>&1")
if not (ok_py == true or ok_py == 0) then
  print("SKIP  flush_provedor_falso_spec: python3 ausente neste ambiente")
  os.exit(0)
end

local tools = require("tools") -- registra o registry real (Read incluso)

local tokbuf = {}
local ui_mock = setmetatable({
  stream_start     = function() tokbuf = {} end,
  stream_confirm   = function() end,
  stream_token     = function(s) tokbuf[#tokbuf + 1] = s end,
  stream_reasoning = function() end,
  stream_end       = function()
    local s = table.concat(tokbuf); tokbuf = {}; return s, ""
  end,
  start_thinking   = function() end,
  stop_thinking    = function() return 0 end,
  update_label     = function() end,
}, { __index = function() return function() end end })

package.preload["ui"] = function() return ui_mock end

package.preload["agent.loop.tool_runner"] = function()
  return {
    run_batch = function(ctx, tool_calls)
      for _, tc in ipairs(tool_calls) do
        local fn   = tc["function"] or tc
        local args = fn.arguments
        if type(args) == "string" then
          local okj, dec = pcall(require("json").decode, args)
          if okj and type(dec) == "table" then args = dec end
        end
        local resultado = tools.call_structured(fn.name, args,
          { skip_pretool = true, disabled_tools = ctx.disabled_tools })
        ctx.msgs[#ctx.msgs + 1] = {
          role = "tool", tool_call_id = tc.id, content = resultado,
        }
      end
    end,
  }
end

local function ler(p)
  local f = io.open(p, "r")
  if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end

local function contar_reqs(logfile)
  local s, n = ler(logfile) or "", 0
  for _ in s:gmatch("REQ%d+ modo=") do n = n + 1 end
  return n
end

local pids = {}
local function matar_todos()
  for _, p in ipairs(pids) do os.execute("kill " .. tostring(p) .. " 2>/dev/null") end
  pids = {}
end

local seq = 0
local function subir(modo)
  seq = seq + 1
  local base = string.format("%s/fp326_%s_%d", TMP, modo, seq)
  local portfile, logfile = base .. ".port", base .. ".log"
  local pidfile, outfile  = base .. ".pid",  base .. ".out"
  os.remove(portfile); os.remove(logfile); os.remove(pidfile)
  os.execute(string.format(
    "%s %q --mode %s --log %q --portfile %q >%q 2>&1 & echo $! > %q",
    PY, SCRIPT, modo, logfile, portfile, outfile, pidfile))
  local porta
  for _ = 1, 100 do
    porta = ler(portfile)
    if porta then break end
    os.execute("sleep 0.1")
  end
  local pid = tonumber((((ler(pidfile) or "")):gsub("%s+", "")))
  if pid then pids[#pids + 1] = pid end
  return tonumber(((porta or ""):gsub("%s+", ""))), logfile
end

local flow   = require("agent.flush")
local prompt = require("memoryflush.prompt").get_flush_prompt({})

local function rodar_flush(porta)
  local ctx = {
    cfg = { agents = { defaults = {
      request = { timeout = 20, idle_timeout = 8, max_retries = 2,
                  mode = "static", retry_static = 1, retry_max = 2 },
      temperature = 0.5 } } },
    active = {
      endpoint = "http://127.0.0.1:" .. tostring(porta) .. "/v1/chat/completions",
      api_key = "", auth_style = "", model_id = "fake-provider-326",
      context_window = 128000, max_tokens = 4096, reasoning = false,
    },
    tokens = 0, msgs = {},
  }
  local new_msgs = {
    { role = "user",      content = "Samuel pediu para investigar o flush (issue #326)." },
    { role = "assistant", content = "Investigando o Memory Flush." },
  }
  local buf = {}
  local _w = io.write
  io.write = function(...)
    local t = table.pack(...)
    for i = 1, t.n do buf[#buf + 1] = tostring(t[i]) end
  end
  local ok, res = pcall(flow.run, ctx, new_msgs, prompt)
  io.write = _w
  return ok, res, table.concat(buf), ctx
end

-- ── (b) Read de arquivo inexistente (H4) ────────────────────────────────────
local porta, log = subir("readmiss")
local ok_b, res_b, saida_b, ctx_b = rodar_flush(porta)
matar_todos()
print("--- log cenário (b) ---"); print(ler(log) or "(vazio)")
local tool_b = ""
for _, m in ipairs(ctx_b.msgs) do
  if m.role == "tool" then tool_b = tool_b .. (m.content or "") end
end
print("--- mensagem tool injetada no contexto do flush ---")
print(tool_b ~= "" and tool_b or "(nenhuma)")
check(ok_b == true,             "cenário (b): flush não lançou erro")
check(res_b == true,            "cenário (b): flush COMPLETA (done=true)")
check(contar_reqs(log) == 2,    "cenário (b): 2 requisições (Read inexistente -> [FLUSH_DONE]); obtido=" .. tostring(contar_reqs(log)))
check(tool_b:find("Arquivo não existe", 1, true) ~= nil,
  "cenário (b): o Read REAL devolve 'Arquivo não existe'")
check(saida_b:find("MAX_ITER", 1, true) == nil,
  "cenário (b): NÃO atinge MAX_ITER (sem laço por arquivo ausente)")

-- ── (c2) HTTP 400 com status numérico -> não repete ─────────────────────────
porta, log = subir("http400s")
local ok_c, res_c, saida_c = rodar_flush(porta)
matar_todos()
print("--- log cenário (c2) ---"); print(ler(log) or "(vazio)")
check(ok_c == true,   "cenário (c2): flush não lançou erro")
check(res_c == false, "cenário (c2): flush aborta com 400 não-retentável")
check(contar_reqs(log) == 1,
  "cenário (c2): 1 requisição (400 com status NÃO repete); obtido=" .. tostring(contar_reqs(log)))
check(saida_c:find("[WARN] Memory Flush aborted (API):", 1, true) ~= nil,
  "cenário (c2): aviso em palavras [WARN] Memory Flush aborted (API):")
check(saida_c:find("⚠", 1, true) == nil, "cenário (c2): sem símbolo ⚠ no aviso")

-- ── (d) resposta vazia -> "Sem resposta do servidor" ────────────────────────
porta, log = subir("empty")
local ok_d, res_d, saida_d = rodar_flush(porta)
matar_todos()
print("--- log cenário (d) ---"); print(ler(log) or "(vazio)")
check(ok_d == true,   "cenário (d): flush não lançou erro")
check(res_d == false, "cenário (d): flush aborta quando o provedor não responde")
check(contar_reqs(log) == 2,
  "cenário (d): 2 requisições (retry em 'Sem resposta do servidor'); obtido=" .. tostring(contar_reqs(log)))
check(saida_d:find("Sem resposta do servidor", 1, true) ~= nil,
  "cenário (d): motivo 'Sem resposta do servidor' presente")
check(saida_d:find("[WARN] Memory Flush aborted (API):", 1, true) ~= nil,
  "cenário (d): aviso em palavras [WARN] Memory Flush aborted (API):")

if falhas > 0 then
  print(("\nFAIL  flush_provedor_falso_spec: %d verificação(ões) falharam"):format(falhas))
  os.exit(1)
end
print("\nPASS  flush_provedor_falso_spec")
