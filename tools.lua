local tools = {}
tools.registry = {}

local PROJECT_ROOT = (os.getenv("HOME") or "/data/data/com.termux/files/home") .. "/.TermAI"

local editor = require("editor")

local function expand_path(path)
  path = path:match("^%s*(.-)%s*$")
  if path:sub(1, 1) == "~" then
    return (os.getenv("HOME") or "/data/data/com.termux/files/home") .. path:sub(2)
  end
  if path:sub(1, 1) == "/" then return path end
  return PROJECT_ROOT .. "/" .. path
end

function tools.register(name, description, func)
    tools.registry[name] = {desc = description, execute = func}
end

tools.register("executar_bash", "Executa comandos shell no sistema. Arg: o comando completo.", function(arg)
    local h = io.popen(arg .. " 2>&1")
    local res = h and h:read("*a") or ""
    if h then h:close() end
    return res == "" and "✅ Comando executado (sem saída de texto)" or res
end)

tools.register("ler_arquivo", "Lê o conteúdo de um arquivo. Arg: caminho (aceita caminhos relativos)", function(arg)
    local path = expand_path(arg)
    local f = io.open(path, "r")
    if not f then return "❌ Erro: Arquivo não existe: "..path end
    local c = f:read("*a")
    f:close()
    return c == "" and "⚠️ O arquivo está vazio." or c
end)

tools.register("escrever_arquivo", "Sobrescreve/Cria um arquivo com backup. Arg: caminho|||conteúdo", function(arg)
    local p = arg:find("|||", 1, true)
    if not p then return "❌ Erro de sintaxe. Use: caminho|||conteudo" end
    local path = expand_path(arg:sub(1, p-1))
    local content = arg:sub(p+3)
    editor.write_safe(path, content)
    return "✅ Gravado em: "..path.." (backup .bak criado se existia)"
end)

tools.register("substituir_texto", "Edita texto com correspondência 100% exata. Arg: caminho|||texto_antigo|||texto_novo", function(arg)
    local p1 = arg:find("|||", 1, true)
    if not p1 then return "❌ Erro: use caminho|||antigo|||novo" end
    local p2 = arg:find("|||", p1+3, true)
    if not p2 then return "❌ Erro: use caminho|||antigo|||novo" end
    local path = expand_path(arg:sub(1, p1-1))
    local old = arg:sub(p1+3, p2-1)
    local new = arg:sub(p2+3)
    local ok, msg = editor.replace_exact(path, old, new)
    return (ok and "✅ " or "❌ ") .. msg
end)

tools.register("buscar_arquivo", "Busca arquivos no workspace. Arg: nome", function(arg)
    local h = io.popen('find ' .. PROJECT_ROOT .. ' -iname "*' .. arg .. '*" 2>/dev/null')
    local res = h and h:read("*a") or ""
    if h then h:close() end
    return res == "" and "❌ Nada encontrado." or "✅ Encontrados:\n" .. res
end)

tools.register("listar_workspace", "Lista conteúdo do workspace. Sem argumentos.", function(arg)
    local cmd = "ls -1 " .. PROJECT_ROOT .. "/workspace 2>&1"
    local h = io.popen(cmd)
    local res = h and h:read("*a") or ""
    if h then h:close() end
    if res == "" or res:match("No such file") then return "❌ Workspace vazio ou inacessível." end
    return "📁 Arquivos do Workspace:\n  • " .. res:gsub("\n", "\n  • ")
end)

function tools.call(cmd_string)
    local t_name, t_arg = cmd_string:match("^([^|]+)|(.*)$")
    if not t_name then return "❌ Erro: Sintaxe inválida." end
    t_name, t_arg = t_name:match("^%s*(.-)%s*$"), t_arg and t_arg:match("^%s*(.-)%s*$") or ""
    local tool = tools.registry[t_name]
    if not tool then return "❌ Erro: Ferramenta '" .. t_name .. "' não existe." end
    local ok, res = pcall(tool.execute, t_arg)
    if not ok then return "❌ Erro interno: " .. tostring(res) end
    return res
end

function tools.get_docs()
    local doc = "FERRAMENTAS NATIVAS DISPONÍVEIS:\n"
    for name, data in pairs(tools.registry) do doc = doc .. "- " .. name .. ": " .. data.desc .. "\n" end
    return doc
end

return tools
