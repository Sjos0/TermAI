-- tools/exec/executor.lua — Execução de comandos shell.
-- Retorna {output, exit_code, timed_out} — sem campo 'partial' (redundante).
-- TMPDIR resolvido por-chamada (per-call) para preservar resolução dinâmica do env var.
local truncator = require("tools.exec.truncator")

local M = {}

local _count = 0  -- contador para evitar colisão de nomes de tmp

-- Lista de comandos de rede proibidos dentro do exec para garantir o uso de ferramentas nativas seguras (web_fetch/web_search)
local BANNED_COMMANDS = { "wget", "lynx", "w3m" }

-- Executa um comando shell e retorna resultado estruturado.
-- command: string do comando
-- timeout: número de segundos (nil = sem timeout)
-- Retorna: {output=string, exit_code=string, timed_out=boolean}
-- on_line (opcional): recebe cada linha de saída enquanto o comando roda (saída parcial, #176 P2).
-- A linha de controle __EXIT__ nunca é repassada. Erro no callback não interrompe a execução.
function M.run(command, timeout, on_line)
  -- Varre de forma robusta por limite de fronteira de palavra (%f) para evitar falsos-bloqueios de substring
  for _, banned in ipairs(BANNED_COMMANDS) do
    if command:match("%f[%w]" .. banned .. "%f[%W]") then
      return {
        output = "[FAIL] [SEGURANÇA] Bloqueio de Comando: O uso do utilitário de rede '" .. banned 
          .. "' dentro da ferramenta 'Exec' é proibido por segurança. Para buscar ou extrair conteúdo de páginas web, você DEVE usar as ferramentas nativas seguras 'web_search' ou 'web_fetch', que possuem salvaguardas de tokens e escudos de SSRF.",
        exit_code = "1",
        timed_out = false
      }
    end
  end

  local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  _count = _count + 1
  local tmp = TMPDIR .. "/termai_exec_" .. os.time() .. "_" .. _count .. ".sh"

  -- Passo 1: criar script temporário
  local f = io.open(tmp, "w")
  if not f then
    return {output = "[FAIL] Erro ao criar arquivo temporário", exit_code = "?", timed_out = false}
  end
  f:write(command .. "\n__ec=$?; echo \"__EXIT__:$__ec\"")
  f:close()

  -- Passo 2: montar runner com/sem timeout
  local runner = timeout
    and ("timeout " .. timeout .. " sh " .. tmp .. " 2>&1")
    or  ("sh " .. tmp .. " 2>&1")

  -- Passo 3: executar e capturar output
  local h   = io.popen(runner)
  local lines = {}
  if h then
    for ln in h:lines() do
      lines[#lines + 1] = ln
      -- A linha de controle pode vir colada ao fim da última linha (sem \n); remove só ela.
      local body, n_exit = ln:gsub("__EXIT__:%d+$", "")
      if on_line and not (n_exit == 1 and body == "") then pcall(on_line, body) end
    end
    h:close()
  end
  -- Mesmo texto que h:read("*a") devolvia: cada linha termina em \n.
  local res = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""

  -- Passo 4: limpar tmp file
  os.remove(tmp)

  -- Passo 5: extrair exit code
  local exit_code = res:match("__EXIT__:(%d+)") or "?"
  res = res:gsub("\n?__EXIT__:%d+\n?$", ""):gsub("%s+$", "")

  -- Passo 6: detectar timeout
  local timed_out = (timeout ~= nil and exit_code == "?")

  -- Passo 7: truncar output (responsabilidade separada)
  local output = truncator.truncate_tail(res)

  return {
    output    = output,
    exit_code = exit_code,
    timed_out = timed_out,
  }
end

return M
