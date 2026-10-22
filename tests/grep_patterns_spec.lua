-- tests/grep_patterns_spec.lua — Grep (issue #91): validação de Lua patterns, aviso de '|',
-- base oculto pesquisável, arquivos sensíveis fora, .git fora, segredo mascarado.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local pattern = require("tools.grep.pattern")
local searcher = require("tools.grep.searcher")
local formatter = require("tools.grep.formatter")

-- (1) Diferencial: a validação concorda com o Lua real em cada caso.
-- Para cada caso: padrão, texto que força o motor a atingir o trecho problemático.
local invalid = {
  { "z%", "z" }, { "(a", "a" }, { "a)%d", "a1" }, { "[a", "a" },
  { "%bx", "x" }, { "%fa", "a" }, { "x%", "x" }, { "a(", "a" },
}
for _, c in ipairs(invalid) do
  local perr = pattern.validate(c[1])
  local ok = pcall(string.find, c[2], c[1])
  check(perr ~= nil and not ok, "inválido '" .. c[1] .. "': validador e Lua concordam (erro)")
end

local valid = {
  { "alpha", "alpha" }, { "%d+", "abc 42" }, { "[a-z]", "x" }, { "%b()", "(x)" },
  { "%f[%w]%w+", "hello" }, { "a%.b", "a.b" }, { "(a)(b)", "ab" }, { "[]]", "]" },
  { "[^]]", "x" }, { "x%%", "x%" }, { "%(", "(" }, { "a[%]]", "a]" },
  { "a)", "x a) y" },
}
for _, c in ipairs(valid) do
  local perr = pattern.validate(c[1])
  local ok = pcall(string.find, c[2], c[1])
  check(perr == nil and ok, "válido '" .. c[1] .. "': validador e Lua concordam (ok)")
end

-- (2) Alternância: '|' é detectado e não é confundido com escape.
check(pattern.has_alternation("a|b"), "has_alternation: a|b")
check(not pattern.has_alternation("alpha"), "has_alternation: sem |")
check(not pattern.has_alternation("a%|b"), "has_alternation: %| é literal, não alternância")

-- (3) Ponta a ponta num base OCULTO (como ~/.TermAI), com arquivos sensíveis e .git.
local base = "/tmp/.grep91_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. base .. "/sub' '" .. base .. "/.git'")
local function write(path, text)
  local f = assert(io.open(path, "w")); f:write(text); f:close()
end
write(base .. "/a.txt", "alpha\nspawn here\ntoken ghp_SECRET123 spawn\n")
write(base .. "/sub/b.lua", "function M.spawn()\n")
write(base .. "/config.json", "api_key = spawn-KEY\n")
write(base .. "/token_notes.txt", "spawn token\n")
write(base .. "/.git/config", "url = https://ghp_GITSECRET@github.com/x\nspawn\n")
os.execute("mkdir -p '" .. base .. "/sub/.hidden' && echo 'spawn oculto' > '" .. base .. "/sub/.hidden/c.md'")

local res, err = searcher.execute({ pattern = "spawn", path = base })
check(res ~= nil and err == nil, "base oculto é pesquisável")
local shown = res and formatter.format(res, "spawn") or ""
check(shown:find("a.txt", 1, true) ~= nil, "encontra arquivo na raiz do base oculto")
check(shown:find("b.lua", 1, true) ~= nil, "encontra arquivo em subpasta visível")
check(shown:find("config.json", 1, true) == nil, "config.json (chaves) fica fora")
check(shown:find("token_notes", 1, true) == nil, "arquivo com 'token' no nome fica fora")
check(shown:find(".git/", 1, true) == nil, ".git fica fora")
check(shown:find("spawn oculto", 1, true) == nil, "subpasta oculta (.hidden) continua fora, documentado")
check(not shown:find("SECRET123", 1, true) and not shown:find("GITSECRET", 1, true),
      "segredo na linha é mascarado antes de mostrar")

-- (4) Padrão com '|' sem resultado: aviso explícito, não silêncio.
local r2 = searcher.execute({ pattern = "alpha|beta", path = base })
check(r2 and r2.match_count == 0 and r2.hint ~= nil, "'|' sem resultado traz aviso (hint)")
check(formatter.format(r2, "alpha|beta"):find("não é alternância", 1, true) ~= nil,
      "o aviso aparece na saída formatada")

-- (5) Padrão inválido: erro explícito, nunca 'nenhum resultado'.
local r3, e3 = searcher.execute({ pattern = "z%", path = base })
check(r3 == nil and e3 and e3:find("inválido", 1, true) ~= nil, "padrão inválido devolve erro explícito")

-- (6) Caminho com aspas simples não quebra o comando.
local weird = base .. "/it's dir"
local wq = weird:gsub("'", "'\\''")
os.execute("mkdir -p '" .. wq .. "' && echo 'spawn aspas' > '" .. wq .. "/x.txt'")
local r4 = searcher.execute({ pattern = "spawn aspas", path = base })
check(r4 and r4.match_count == 1, "caminho com aspas simples é tratado sem injetar comando")

os.execute("rm -rf '" .. base .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
