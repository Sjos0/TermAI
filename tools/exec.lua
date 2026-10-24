-- tools/exec.lua — Fachada da tool "Exec".
-- v4: refatoração para facade + 3 submódulos (constants, truncator, executor).
--     Comportamento idêntico ao v3 — zero mudança de retorno para o modelo.
--     Descriptions permanecem aqui (responsabilidade de interface).
-- Integrado com a nova camada de segurança e gerenciador de permissões
-- (tools.exec.security e tools.exec.permissions chamados no hook central PreToolUse).
local executor = require("tools.exec.executor")

local M = {}

function M.register(tools)
  tools.register("Exec",
    [==[Run a shell command on the device and return its output. Use it for system work that no dedicated tool covers: git, builds, luac, package and process commands. Do not use it to read, search, create or edit files when Read, Grep, Find, Write or Edit can do the job; those tools return less noise and are safer. Run independent commands as separate Exec calls, and chain dependent commands with '&&'. Prefer absolute paths over 'cd', and always quote paths that contain spaces. Output over 2000 lines or 100 KB is truncated. On timeout you get the partial output; raise 'timeout' for slow network commands. Never use echo to simulate output. Example: command 'git status'.]==],
    function(arg)
      -- Passo 1: parsing e normalização (responsabilidade de interface)
      local cmd     = type(arg) == "table" and (arg.command or arg.arg or "") or arg
      -- v4.1: Aplica timeout de 30 segundos por padrão para evitar congelamentos do Lua thread em I/O lentos
      local timeout = type(arg) == "table" and tonumber(arg.timeout) or 30
      if cmd == "" then return "❌ Argumento vazio: informe o comando." end
      if timeout then timeout = math.min(math.max(math.floor(timeout), 1), 300) end

      -- Passo 2: delegar execução
      local result = executor.run(cmd, timeout)

      -- Passo 3: formatar mensagem final (responsabilidade de interface)
      if result.timed_out then
        local partial = result.output ~= "" and ("\nSaída parcial:\n" .. result.output) or ""
        return "❌ Timeout: comando interrompido após " .. timeout .. "s" .. partial
      end

      if result.output == "" then
        return result.exit_code == "0"
          and "✅ Comando executado (sem saída de texto)"
          or  "❌ Comando falhou | Exit: " .. result.exit_code .. " | sem saída de texto"
      end

      if result.exit_code ~= "0" then
        return result.output .. "\n⚠️ Exit code: " .. result.exit_code
      end

      return result.output
    end,
    {
      type = "object",
      properties = {
        command = {
          type        = "string",
          description = "Shell command to run on the device. "
                      .. "Examples: 'ls -la ~/TermAI/', 'luac -p file.lua', "
                      .. "'git status', 'mkdir -p ~/TermAI/backup && cp *.lua ~/TermAI/backup/'"
        },
        timeout = {
          type        = "number",
          description = "Timeout in seconds (1-300). The command is stopped when it exceeds it. "
                       .. "Use it for slow network or build commands. Default: 30 s (max 300 s)."
        }
      },
      required = {"command"}
    }
  )
end

return M
