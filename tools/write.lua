-- tools/write.lua — Ferramenta "Write".
-- v2: schema JSON para native tool calling + arg backward compat (string|tabela).
local M = {}

function M.register(tools_mod, helpers)
  local expand    = helpers.expand_path
  local file_info = helpers.file_info
  local luac_val  = helpers.luac_validate
  local mem       = require("tools.memory")
  local engine    = require("tools.write.write_engine")

  tools_mod.register("Write",
    [==[Create a new file, or overwrite an existing file completely, and create any missing parent directories. Use it only for new files or full rewrites. Do not use it to change part of an existing file; use Edit for that. Read the file first to confirm its current state before overwriting it. Lua files are syntax-checked with 'luac -p' after writing, and the result is returned. Paths are relative to the workspace or absolute; never prefix them with 'workspace/'.]==],
    function(arg)
      local path, content
      if type(arg) == "table" then
        -- v2: {path=..., content=...}
        path    = expand(arg.path or "")
        content = arg.content or ""
      else
        -- Legado: caminho|||conteudo
        local p = arg:find("|||", 1, true)
        if not p then return "Erro de sintaxe. Use: caminho|||conteudo" end
        path    = expand(arg:sub(1, p - 1))
        content = arg:sub(p + 3)
      end

      local ok, msg = engine.write_safe(path, content)
      if not ok then return msg or "Falha na escrita" end
      if path:find("/memory/", 1, true) then mem.invalidate_cache() end
      local info     = file_info(content)
      local luac_msg = luac_val(path)
      local out = "Gravado em: " .. path .. "\n" .. info
      if luac_msg then out = out .. "\n" .. luac_msg end
      return out
    end,
    -- v2: Schema JSON
    {
      type = "object",
      properties = {
        path = {
          type = "string",
          description = "Path of the file to create or overwrite, relative to the workspace or absolute. Never prefix it with 'workspace/'."
        },
        content = {
          type = "string",
          description = "Complete file content. Lua files are syntax-checked with 'luac -p' after writing."
        }
      },
      required = {"path", "content"}
    }
  )
end

return M
