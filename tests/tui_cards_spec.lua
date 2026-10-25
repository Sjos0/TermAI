-- tests/tui_cards_spec.lua — Cards de tool e avisos de subagente na TUI: nada quebra a largura da tela,
-- sem rótulo de origem, aviso agrupado, e o main_loop não imprime linha falsa de usuário.
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function plain(s) return (s:gsub("\27%[[%d;]*m", "")) end
local function width(s) return utf8.len(plain(s)) or #plain(s) end

local root = portable_tmp.name("termai_cards_test")
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
require("tools.agents.paths").base_override = root

local header   = require("ui.tools_init.header")
local core     = require("ui.core")
local block    = require("ui.subagent_block")
local registry = require("tools.subagents.registry")
local subs     = require("tools.subagents")
local TW       = core.tw()

-- (1) Corte por caracteres UTF-8 para caber em N colunas.
check(header.cut_cols("abcdef", 4) == "abc…", "cut_cols: corta e marca com …")
check(header.cut_cols("ação", 10) == "ação", "cut_cols: texto que cabe fica igual")
check(utf8.len(header.cut_cols("áéíóúçãõ", 3)) == 3, "cut_cols: conta caracteres, não bytes")

-- (2) Cabeçalho: colunas e largura real na tela.
check(header.header_vis_len("Read", "a.lua", 40) == 2 + 4 + 3 + 5, "header_vis_len: conta colunas")
check(header.header_vis_len("Read", string.rep("x", 300), TW) <= TW - 1, "header_vis_len: nunca passa de tw-1")
local out = {}
local orig = io.write
io.write = function(...) for _, v in ipairs({ ... }) do out[#out + 1] = tostring(v) end end
header.write_header(core.c.yellow, "Exec", string.rep("comando muito longo ", 20))
io.write = orig
local line = table.concat(out)
check(width(line) <= TW, "cabeçalho com argumento longo cabe em uma linha (" .. width(line) .. " de " .. TW .. ")")
check(not line:find("\n.", 1, true), "cabeçalho termina numa única quebra de linha")

-- (3) Subagente: sem linha de lançamento e sem rótulo de origem.
registry.save({ runId = "sub-c1", kind = "clone", agentId = "main", task = "pesquisar X", status = "running",
  created_at = os.time(), parent_agent = "main", cleanup = "retain", announce_consumed = false })
check(#block.pending_lines("main") == 0, "lançamento: nenhuma linha própria do subagente")
check(block.flush("main", true, nil) == false, "lançamento: flush não escreve nada")

-- (4) Aviso de término: linha de sistema, prévia curta, cabe na tela, sem rótulo de origem.
registry.save({ runId = "sub-c2", kind = "clone", agentId = "main", task = "t", status = "completed",
  created_at = os.time() - 9, started_at = os.time() - 8, finished_at = os.time(),
  parent_agent = "main", cleanup = "retain", announce_consumed = false })
registry.write_result("sub-c2", string.rep("resultado com acentuação ção ", 20))
local done = plain(block.end_line(registry.load("sub-c2")))
check(done:find("concluído", 1, true) ~= nil, "término: diz que concluiu")
check(width(done) <= TW - 1, "término: cabe na largura da tela (" .. width(done) .. ")")
check(not done:find("lançado", 1, true) and not done:find("orquestrador", 1, true), "término: sem rótulo de origem")

registry.save({ runId = "sub-c3", kind = "clone", agentId = "main", task = "t", status = "failed",
  created_at = os.time() - 9, parent_agent = "main", cleanup = "retain", announce_consumed = false,
  error = "[ERRO] Falha apos 5 tentativas - Sem resposta do servidor " .. string.rep("x", 200) })
local failed = plain(block.end_line(registry.load("sub-c3")))
check(failed:find("falhou", 1, true) ~= nil, "falha: diz que falhou")
check(width(failed) <= TW - 1, "falha: cabe na largura da tela (" .. width(failed) .. ")")

-- (5) Agrupamento: o pai só acorda com término e sem filho ativo, ou 5 s depois do primeiro término.
registry.save({ runId = "sub-c4", kind = "clone", agentId = "main", task = "t", status = "running",
  created_at = os.time(), parent_agent = "main", cleanup = "retain", announce_consumed = false })
check(subs.has_pending({ agent_id = "main" }) == false,
  "agrupamento: término recente com filho ainda ativo NÃO acorda o pai")
check(subs.active_count({ agent_id = "main" }) >= 1, "active_count: conta o filho ativo")

-- (6) main_loop não imprime mais a linha falsa de usuário do aviso.
local ml = io.open("agent/main_loop.lua"):read("*a")
check(not ml:find("↻ subagentes concluídos", 1, true), "main_loop: aviso não aparece como digitação do usuário")
check(ml:find("not wake then goto continue", 1, true) ~= nil, "main_loop: o aviso é processado mesmo com entrada vazia")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
