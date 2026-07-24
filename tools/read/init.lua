-- tools/read/init.lua — Ferramenta "Read".
-- v2: schema JSON para native tool calling + arg backward compat (string|tabela).
-- v3: grep removido — agora é ferramenta standalone "Grep" (tools/grep.lua).
local parser       = require("tools.read.parser")
local full_reader  = require("tools.read.full_reader")
local range_reader = require("tools.read.range_reader")
local M = {}

function M.register(tools, helpers)
  local expand    = helpers.expand_path
  local file_info = helpers.file_info

  tools.register("Read",
    "Reads the content of a single specific file in the system.\n"
    .. "Use ONLY when you already know the exact file path (previously found via Grep or Find).\n"
    .. "For medium or large files, you should ALWAYS pass start_line and end_line parameters to surgically extract only the needed block, saving context resources.",
    function(arg)
      -- v2: arg pode ser tabela (native) ou string (legado)
      local parsed
      if type(arg) == "table" then
        if arg.start_line then
          parsed = {
            path = arg.path or "",
            mode = "range",
            ls   = tonumber(arg.start_line),
            le   = tonumber(arg.end_line or arg.start_line),
          }
        else
          parsed = {path = arg.path or "", mode = "full"}
        end
      else
        parsed = parser.parse(arg)
      end

      local file_path = expand(parsed.path)

      -- Válvula de segurança 0: Impede leitura se for um diretório
      local ok_dir, _, exit_code = os.execute("test -d " .. string.format("%q", file_path))
      if ok_dir == true or ok_dir == 0 or exit_code == 0 then
        return "❌ Erro: '" .. file_path .. "' é um diretório, não um arquivo."
      end

      local f = io.open(file_path, "r")
      if not f then return "❌ Arquivo não existe: " .. file_path end

      -- Válvula de segurança 1: impede leitura de arquivos maiores que 50KB (padrão OpenClaw)
      local size = f:seek("end")
      f:seek("set", 0)
      if size > 50 * 1024 and parsed.mode == "full" then
        f:close()
        return string.format("❌ Erro: O arquivo possui %.1f KB, o que excede o limite seguro de leitura completa de 50KB.\n"
          .. "  Para evitar estourar sua janela de contexto e economizar tokens, use a leitura por intervalo (start_line / end_line).", size / 1024)
      end

      local content = f:read("*a"); f:close()
      if not content or content == "" then return "⚠️ O arquivo está vazio." end

      -- Válvula de segurança 2: impede leitura de arquivos com mais de 2000 linhas (padrão OpenClaw)
      local lines_count = 0
      for _ in content:gmatch("\n") do lines_count = lines_count + 1 end
      if content:sub(-1) ~= "\n" then lines_count = lines_count + 1 end

      if lines_count > 2000 and parsed.mode == "full" then
        return string.format("❌ Erro: O arquivo possui %d linhas, o que excede o limite seguro de leitura completa de 2000 linhas.\n"
          .. "  Para evitar estourar sua janela de contexto e economizar tokens, use a leitura por intervalo (start_line / end_line).", lines_count)
      end

      local info = file_info(content)

      if parsed.mode == "range" then
        return range_reader.read(file_path, content, info, parsed.ls, parsed.le)
      else
        return full_reader.read(file_path, content, info)
      end
    end,
    -- v2: Schema JSON (formato OpenAI)
    {
      type = "object",
      properties = {
        path = {
          type = "string",
          description = "Full or relative path of the file to inspect."
        },
        start_line = {
          type = "integer",
          description = "Starting line number to focus reading only on the relevant range."
        },
        end_line = {
          type = "integer",
          description = "Ending line number to focus reading only on the relevant range."
        }
      },
      required = {"path"}
    }
  )
end

return M
