-- tools/editor.lua — Ferramenta "Edit".
-- v2: schema JSON com edits array; suporte a arg string (legado) e tabela (native).
-- v3: captura conteúdo antes da edição; result_builder monta diff visual.
local editor = {}
local engine         = require("tools.editor.edit_engine")
local result_builder = require("tools.editor.result_builder")
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil, "arquivo nao encontrado: " .. path end
  local c = f:read("*a"); f:close()
  return c
end
local function write_file(path, content)
  local f = io.open(path, "w")
  if not f then return false, "falha ao abrir para escrita: " .. path end
  f:write(content); f:close()
  return true
end
function editor.replace_multi(path, patches)
  return engine.replace_multi(path, patches, read_file, write_file)
end
function editor.replace_exact(path, old_text, new_text)
  return engine.replace_exact(path, old_text, new_text, read_file, write_file)
end
function editor.register_tools(tools_mod, helpers)
  local expand    = helpers.expand_path
  local file_info = helpers.file_info
  local luac_val  = helpers.luac_validate
  local mem       = require("tools.memory")
  tools_mod.register("Edit",
    [==[Use it to change an existing file: replace a line range or an exact piece of text. The preferred form gives start_line, end_line and new_text, which replaces that range. The fallback form gives old_text and new_text, for an exact match. Read the file first to confirm the current line numbers and text. Edits apply from the bottom up, so line numbers stay valid while several edits run. An empty new_text deletes the range. Lua files are syntax-checked after editing. Do not use it to create a new file; use Write for that.]==],
    function(arg)
      if type(arg) == "table" then
        -- v2: JSON structured {path, edits:[{old_text?,new_text,start_line?,end_line?}]}
        local path_raw = arg.path or ""
        local edits_in = arg.edits or {}
        if path_raw == "" then return "Error: campo 'path' é obrigatório" end
        if #edits_in == 0  then return "Error: campo 'edits' não pode ser vazio" end
        local path_exp = expand(path_raw)
        local edits = {}
        for i, e in ipairs(edits_in) do
          if e.start_line then
            edits[#edits + 1] = {
              type = "lines",
              ls   = tonumber(e.start_line),
              le   = tonumber(e.end_line or e.start_line),
              new  = e.new_text or "",
            }
          elseif e.old_text then
            edits[#edits + 1] = {old = e.old_text, new = e.new_text or ""}
          else
            return string.format("Error: edit[%d] precisa de 'old_text' ou 'start_line'", i)
          end
        end
        -- v3: captura conteudo ANTES da edicao para montar o diff depois.
        local before_content = read_file(path_exp)
        local ok, msg = editor.replace_multi(path_exp, edits)
        if path_exp:find("/memory/", 1, true) then mem.invalidate_cache() end
        if not ok then return "❌ " .. (msg or "Edit failed") end
        return result_builder.build(path_exp, msg, edits, before_content, file_info, luac_val)
      else
        -- Legado: formato merge conflict (<<<<<<< SEARCH / ======= / >>>>>>> REPLACE)
        local edit_parser = require("tools.editor.edit_parser")
        local path_p, edits_p, err = edit_parser.parse(arg)
        if not path_p then return "Error: " .. (err or "invalid format") end
        path_p = expand(path_p)
        -- v3: captura conteudo ANTES da edicao para montar o diff depois.
        local before_content = read_file(path_p)
        local ok, msg = editor.replace_multi(path_p, edits_p)
        if path_p:find("/memory/", 1, true) then mem.invalidate_cache() end
        if not ok then return "❌ " .. (msg or "Edit failed") end
        return result_builder.build(path_p, msg, edits_p, before_content, file_info, luac_val)
      end
    end,
    -- v2: Schema JSON
    {
      type = "object",
      properties = {
        path = {
          type = "string",
          description = "Path of the file to edit. Read it first to confirm line numbers and text."
        },
        edits = {
          type = "array",
          description = "Replacements to apply. They are applied from the bottom up, so line numbers stay valid.",
          items = {
            type = "object",
            properties = {
              old_text = {
                type = "string",
                description = "Exact text to find. Copy it from Read; never invent it. Use it only when you have no line numbers."
              },
              new_text = {
                type = "string",
                description = "Replacement text. An empty string deletes the range."
              },
              start_line = {
                type = "integer",
                description = "First line of the range to replace. Preferred: no copy errors."
              },
              end_line = {
                type = "integer",
                description = "Last line of the range, inclusive. Omit it to replace only start_line."
              }
            },
            required = {"new_text"}
          }
        }
      },
      required = {"path", "edits"}
    }
  )
end
return editor
