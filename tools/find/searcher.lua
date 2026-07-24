-- tools/find/searcher.lua — Implementação física da busca de arquivos.
-- v3: Suporta busca dinâmica em qualquer diretório (seguro), expandindo o potencial do agente.
local M = {}

function M.run(arg, helpers)
  local shell_safe = helpers.shell_safe
  local expand     = helpers.expand_path
  local root       = helpers.PROJECT_ROOT

  local name, search_dir
  if type(arg) == "table" then
    name       = arg.name or arg.arg or ""
    search_dir = arg.dir
  else
    name = arg
  end

  local safe_name = shell_safe(name)
  if safe_name == "" or safe_name:match("^%s*$") then
    return "❌ Nome de busca inválido."
  end

  -- Define o diretório de busca (padrão: workspace)
  local dir = root .. "/workspace"
  if search_dir and search_dir ~= "" then
    dir = expand(search_dir)
  end

  local cmd = string.format('find "%s" -iname "*%s*" 2>/dev/null', dir, safe_name)
  local h = io.popen(cmd)
  local res = h and h:read("*a") or ""
  if h then h:close() end

  if res == "" then
    -- Fuzzy fallback: sugere arquivo com nome ortograficamente proximo
    local fuzzy = require("tools.error_feedback.fuzzy_match")
    local list_cmd = string.format('find "%s" -type f 2>/dev/null', dir)
    local lh = io.popen(list_cmd)
    local candidates = {}
    local path_map = {}
    if lh then
      for path in lh:lines() do
        local filename = path:match("([^/]+)$")
        if filename then
          candidates[#candidates + 1] = filename
          path_map[filename] = path
        end
      end
      lh:close()
    end

    local best, dist = fuzzy.find_closest(safe_name, candidates)
    if best and dist <= 4 then
      local best_path = path_map[best]
      local visual_dir = root .. "/workspace"
      if best_path:sub(1, #visual_dir) == visual_dir then
        best_path = best_path:gsub(visual_dir .. "/", "")
      end
      return string.format("❌ Nenhum arquivo encontrado para '%s' dentro de: %s\n"
        .. "  💡 Você quis dizer: '%s' (caminho: %s)?", safe_name, dir, best, best_path)
    end

    return "❌ Nenhum arquivo encontrado para '" .. safe_name .. "' dentro de: " .. dir
  end

  -- Se a busca for dentro do workspace, simplifica o caminho visualmente
  local visual_dir = root .. "/workspace"
  if dir:sub(1, #visual_dir) == visual_dir then
    res = res:gsub(visual_dir .. "/", "")
  end

  local count = select(2, res:gsub("\n", "\n"))
  return "✅ " .. count .. " arquivo(s) encontrado(s) em " .. dir .. ":\n" .. res
end

return M
