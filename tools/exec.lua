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
    "Execute bash/shell commands on the system. "
    .. "ABSOLUTE RULE: ONLY run real system commands. Never use 'echo' to mock outputs — this is hallucination. "
    .. "IMPORTANT: Avoid using this tool for file operations when dedicated tools exist. Use the appropriate tool instead: "
    .. "Find (NOT find/ls), Grep (NOT grep/rg), Read (NOT cat/head/tail), Edit (NOT sed/awk), Write (NOT echo/cat <<EOF). "
    .. "Multiple commands: For independent commands, make separate Exec calls. For dependent commands, chain with '&&'. Use ';' only when earlier failures don't matter. "
    .. "Paths: Prefer absolute paths over 'cd'. Always quote paths containing spaces. Before creating files, verify the parent directory exists with 'ls'. "
    .. "Outputs exceeding 2000 lines or 100KB are automatically truncated. Use 'timeout' parameter for blocking commands (curl, ssh).",
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
          description = "Full bash command to execute in Termux. "
                      .. "Examples: 'ls -la ~/TermAI/', 'luac -p arquivo.lua', "
                      .. "'git status', 'mkdir -p ~/TermAI/backup && cp *.lua ~/TermAI/backup/'"
        },
        timeout = {
          type        = "number",
          description = "Timeout em segundos (1-300). Interrompe o comando se exceder. "
                       .. "Use para: ssh, curl, compilações longas. Default: 30s (máx 300s)."
        }
      },
      required = {"command"}
    }
  )
end

return M
