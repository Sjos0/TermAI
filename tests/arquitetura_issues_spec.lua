package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/arquitetura_issues_spec.lua — decisões do Arquiteto: #51, #52, #58, #70, #71.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local fonte = require("tests.helpers.fonte")
local function rd(p) local f = io.open(p, "r"); if not f then return "" end; local s = f:read("*a"); f:close(); return s end

-- #52: dono único de format_arg_str (caracterização: mesmos resultados do bloco original)
local tools = require("tools")
check(type(tools.format_arg_str) == "function", "#52: tools.format_arg_str existe (dono único)")
check(tools.format_arg_str("Grep", { pattern = "foo", path = "src" }) == '"foo" in src', "#52: Grep formata padrão e caminho")
check(tools.format_arg_str("Read", { path = "a.lua", start_line = 3, end_line = 9 }) == "a.lua:3-9", "#52: Read com intervalo")
check(tools.format_arg_str("Exec", { command = "ls -la" }) == "ls -la", "#52: campo command vira primário")
check(tools.format_arg_str("calculate", { expression = "2+2" }) == "2+2", "#52: campo expression vira primário")
check(tools.format_arg_str("X", { foo = 1 }):find('"foo"', 1, true) ~= nil, "#52: sem campo conhecido cai para JSON")
check(tools.format_arg_str("X", "texto cru") == "texto cru", "#52: argumento não-tabela vira texto")
check(not fonte.ler("agent/loop/tool_runner/executor"):find("build_arg_str", 1, true), "#52: executor não tem terceira cópia (build_arg_str removido)")

-- #51: grupo Read roda PreToolUse ANTES da UI de grupo, e não executa de novo com skip_pretool
local ex = fonte.ler("agent/loop/tool_runner/executor")
local body = ex:match("local function executar_grupo_read.-\nend\n") or ""
local i_hook = body:find('"PreToolUse"', 1, true)
local i_ui = body:find("ui.tool_group_read_start", 1, true)
check(i_hook and i_ui and i_hook < i_ui, "#51: PreToolUse acontece antes de ui.tool_group_read_start")
check(body:find("skip_pretool = true", 1, true) ~= nil, "#51: chamada de grupo usa skip_pretool (não roda o hook duas vezes)")
check(body:find("PERMISSÃO NEGADA", 1, true) ~= nil, "#51: permissão negada não executa a tool")

-- #58: menu raiz da CLI na mesma numeração da TUI
local cli = rd("commands/config_cli.lua")
local expected = { { "1", "flush" }, { "2", "request" }, { "3", "thinking" }, { "4", "hooks" },
  { "5", "skills" }, { "6", "web_tools" }, { "7", "connectors" } }
local ok58 = true
for _, p in ipairs(expected) do
  if not cli:find('ch == "' .. p[1] .. '" then load_menu("' .. p[2] .. '")', 1, true) then ok58 = false end
end
check(ok58, "#58: CLI mapeia 1..7 para os mesmos submenus da TUI")
check(cli:find("1.", 1, true) and cli:find("Memory Flush", 1, true) and cli:find("Pesquisa Web", 1, true) ~= nil,
  "#58: rótulos do menu raiz seguem a ordem da TUI")

-- #70: get_docs lista os comandos da TUI e não manda o modelo usar Exec
local avail = require("commands.available")
local docs = avail.get_docs()
check(docs ~= "" and docs:find("/config", 1, true) ~= nil, "#70: get_docs não é vazio e cita /config")
check(not docs:find("Exec", 1, true), "#70: texto não manda executar comando via Exec")
check(docs:find("não são ferramentas", 1, true) ~= nil, "#70: deixa claro que comandos não são ferramentas")

-- #71: contrato de nomes documentado, sem rename (nomes continuam registrados)
local tl = rd("lib/tools.lua")
check(tl:find("Contrato de nomes (issue #71", 1, true) ~= nil, "#71: contrato de nomes no topo de tools.lua")
check(tools.registry["Grep"] ~= nil and tools.registry["web_fetch"] ~= nil and tools.registry["web_search"] ~= nil,
  "#71: nomes existentes continuam registrados (sem rename)")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
