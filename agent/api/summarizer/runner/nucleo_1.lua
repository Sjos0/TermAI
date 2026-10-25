-- agent/api/summarizer/runner/nucleo_1.lua — helpers internos: kill_curl, start_curl.
return function(M)
  local P = require("agent.api.summarizer.runner.nucleo")(M)


  -- Mata o curl da tentativa atual. TERM primeiro; KILL se ainda vivo.
  -- PID inválido/vazio é no-op (não chama kill cego).
  local function kill_curl(pid)
    if not pid or type(pid) ~= "string" or not pid:match("^%d+$") then
      return
    end
    os.execute("kill -TERM " .. pid .. " 2>/dev/null")
    local still = io.popen("kill -0 " .. pid .. " 2>/dev/null; echo $?")
    local code = still and still:read("*a") or "1"
    if still then still:close() end
    code = (code or ""):match("%d+") or "1"
    if code == "0" then
      os.execute("kill -KILL " .. pid .. " 2>/dev/null")
    end
  end


  -- Dispara curl em background e devolve o PID (string numérica) ou nil + err.
  local function start_curl(cmd_body)
    local wrapper = "(" .. cmd_body .. " & echo $!)"
    local h = io.popen(wrapper)
    if not h then
      return nil, "falha ao disparar curl (popen)"
    end
    local pid = (h:read("*l") or ""):match("^%s*(%d+)%s*$")
    h:close()
    if not pid then
      return nil, "PID do curl inválido"
    end
    return pid
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.kill_curl = kill_curl
  N.start_curl = start_curl
  return N
end
