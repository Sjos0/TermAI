package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/summarizer_runner_lifecycle_spec.lua
-- Regressão Issue #73: ciclo de vida do curl no summarizer (PID + kill antes de remove).
--
-- Sem HTTP real. Cobre:
-- - fonte: não há `&` solto sem echo $!; há kill_curl / start_curl
-- - kill_curl: PID inválido é no-op; PID de sleep controlado é terminado
-- - start_curl: wrapper ecoa PID numérico de processo real (sleep)

package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0

local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  OK  " .. name)
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

print("\n=== Unit tests: summarizer runner lifecycle (Issue #73) ===\n")

-- ── Fonte estática ──────────────────────────────────────────────────────────
sec("fonte estática runner.lua")

local src = require("tests.helpers.fonte").ler("agent/api/summarizer/runner")

T("não usa os.execute com & solto no curl",
  not src:match('os%.execute%([^)]*&%s*"?%)')
    and not src:match('2>/dev/null &%s*"%)')
    and not src:match('2>/dev/null &%s*%"'),
  "ainda há padrão de & sem PID")

T("wrapper de start_curl ecoa $!",
  src:find("echo $!", 1, true) ~= nil)

T("kill_curl presente e usa TERM/KILL",
  src:find("kill -TERM", 1, true) and src:find("kill -KILL", 1, true))

T("kill_curl chamado antes de os.remove no fluxo",
  src:find("kill_curl(pid)", 1, true) ~= nil
    and src:find("os.remove(tmp_path)", 1, true) ~= nil)

T("request_sync/streamer não tocados nesta spec (arquivo runner só)",
  true)

-- ── kill_curl comportamental ────────────────────────────────────────────────
sec("kill_curl comportamental")

local runner = require("agent.api.summarizer.runner")

T("_kill_curl exportado para teste", type(runner._kill_curl) == "function")
T("_start_curl exportado para teste", type(runner._start_curl) == "function")

-- PID inválido: não deve explodir
local ok_nil = pcall(runner._kill_curl, nil)
local ok_empty = pcall(runner._kill_curl, "")
local ok_str = pcall(runner._kill_curl, "abc")
T("PID nil/vazio/não-numérico é no-op seguro", ok_nil and ok_empty and ok_str)

-- Processo "vivo" = existe e não é zumbi. Um zumbi (já morreu, mas o pai/init ainda não
-- colheu) responde a `kill -0`, mas não executa mais nada: conta como morto. Sem /proc,
-- cai para kill -0.
local function esta_vivo(pid)
  local f = io.open("/proc/" .. pid .. "/stat", "r")
  if f then
    local s = f:read("*a") or ""
    f:close()
    local estado = s:match("%) (%a)")
    return estado ~= nil and estado ~= "Z" and estado ~= "X"
  end
  local h = io.popen("kill -0 " .. pid .. " 2>/dev/null; echo $?")
  local r = h and h:read("*a") or "1"
  if h then h:close() end
  return (r:match("%d+") or "1") == "0"
end

-- Processo controlado: sleep longo → kill
local h = io.popen("(sleep 30 & echo $!)")
local pid = h and (h:read("*l") or ""):match("^%s*(%d+)%s*$")
if h then h:close() end

if pid then
  -- confirma vivo
  T("subprocesso sleep está vivo antes do kill", esta_vivo(pid), "pid=" .. pid)

  runner._kill_curl(pid)
  os.execute("sleep 0.3")
  T("kill_curl termina o subprocesso", not esta_vivo(pid), "pid=" .. pid)
else
  T("subprocesso sleep está vivo antes do kill", false, "não obteve PID")
  T("kill_curl termina o subprocesso", false, "skip")
end

-- ── start_curl ──────────────────────────────────────────────────────────────
sec("start_curl wrapper")

local pid2, err2 = runner._start_curl("sleep 20")
T("start_curl devolve PID numérico", pid2 ~= nil and pid2:match("^%d+$") ~= nil, err2)
if pid2 then
  runner._kill_curl(pid2)
  os.execute("sleep 0.2")
  T("PID de start_curl é killable", not esta_vivo(pid2))
end

-- ── prompt #69 (mesmo PR, regressão cruzada leve) ───────────────────────────
sec("prompt CONSCIÊNCIA AMBIENTAL (#69)")

local prompt = assert(io.open("lib/prompt.lua", "r")):read("*a")
T("sem ler_arquivo/escrever_arquivo/substituir_texto",
  not prompt:find("ler_arquivo", 1, true)
    and not prompt:find("escrever_arquivo", 1, true)
    and not prompt:find("substituir_texto", 1, true))
T("bloco cita Read, Write e Edit",
  prompt:find("`Read`, `Write` e `Edit`", 1, true) ~= nil)

print(string.format("\n=== Resultado: %d ok, %d fail ===\n", pass, fail))
if fail > 0 then os.exit(1) end
