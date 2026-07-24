-- tools/list/lister.lua — Implementação física da listagem de diretórios.
-- v3: Suporta listagem de subpastas de qualquer diretório dinâmico com profundidade limite.
local M = {}

function M.run(arg, helpers)
  local expand = helpers.expand_path
  local root   = helpers.PROJECT_ROOT

  -- Define o diretório de listagem (padrão: workspace)
  local target_dir = root .. "/workspace"
  if type(arg) == "table" and arg.dir and arg.dir ~= "" then
    target_dir = expand(arg.dir)
  end

  local cmd = string.format('find "%s" -mindepth 1 -maxdepth 3 2>/dev/null | sed "s|^%s/||" | sort', target_dir, target_dir)
  local h = io.popen(cmd)
  local res = h and h:read("*a") or ""
  if h then h:close() end

  if res == "" or res:match("No such file") then
    return "❌ Diretório vazio ou inacessível: " .. target_dir
  end

  return "📁 Conteúdo de " .. target_dir .. ":\n  • " .. res:gsub("\n", "\n  • ")
end

return M
