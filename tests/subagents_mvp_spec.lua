-- tests/subagents_mvp_spec.lua — Clone efêmero do agente (sessions_spawn).
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- Captura tudo que for escrito com io.write durante fn().
local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, err = pcall(fn)
  io.write = orig
  assert(ok, err)
  return table.concat(buf)
end

-- Stub do loop: simula um turno do clone e captura o que ele recebeu.
local seen = {}
package.loaded["agent.loop"] = {
  rodar = function(ctx, input, role, max_iter)
    seen.ctx, seen.input, seen.role, seen.max = ctx, input, role, max_iter
    seen.sink_active = require("ui.stream").get_sink() ~= nil
    seen.leak = capture(function()
      local st = require("ui.stream")
      st.stream_reasoning("raciocínio interno")
      st.stream_token("texto do clone")
    end)
    return seen.reply or "resposta final", 0, false, seen.overflow or false, true, ""
  end,
}

local tools    = require("tools")
local spawn    = require("tools.subagents.spawn")
local subs     = require("tools.subagents")
local display  = require("agent.loop.tool_runner.display")
local ui_sub   = require("ui.subagent")
local stream   = require("ui.stream")

check(tools.registry.sessions_spawn ~= nil, "registry tem sessions_spawn")
check(tools.registry.subagents_wait == nil and tools.registry.subagents_listar == nil,
  "subagents_* removidas do registry")

check(display.tc_display({ name = "sessions_spawn", args = { task = "pesquisar X" } })
  == "Subagente | pesquisar X", "tc_display mostra 'Subagente | tarefa'")

check(spawn.spawn({}, {}):match("^❌") ~= nil, "task vazia é recusada")
check(spawn.spawn({ task = "  " }, {}):match("^❌") ~= nil, "task só com espaços é recusada")
check(spawn.spawn({ task = "x" }, nil):match("^❌") ~= nil, "sem pai ativo é recusado")
check(spawn.spawn({ task = "x" }, { is_subagent = true }):match("profundidade") ~= nil,
  "clone não pode criar outro clone")

local parent = {
  cfg = { agents = { defaults = {} } }, active = { name = "m" }, MAX_ITER = 20,
  agent_id = "main", workspace = "/tmp", msgs = { { role = "user", content = "oi" } },
}
local before_sink = stream.get_sink()
subs.bind(parent)
local out = spawn.spawn({ task = "faça X" }, parent)

check(out == "resposta final", "retorna a resposta final do clone")
check(seen.ctx and seen.ctx.is_subagent == true, "clone roda com is_subagent=true")
check(seen.ctx and seen.ctx.disabled_tools.sessions_spawn == true, "clone não vê sessions_spawn")
check(seen.max == 8, "MAX_ITER do clone limitado a 8")
check(seen.input == "faça X" and seen.role == "user", "tarefa entra uma única vez como user")
check(seen.sink_active == true, "sink silencioso ativo durante o clone")
check(seen.leak == "", "texto e raciocínio do clone não aparecem na TUI")
check(stream.get_sink() == before_sink, "sink original restaurado após o clone")
check(subs.current() == parent, "vínculo do pai restaurado após o clone")
check(#parent.msgs == 1, "contexto do pai não foi alterado pelo clone")

seen.overflow = true
local err = spawn.spawn({ task = "grande" }, parent)
check(err:match("estourou") ~= nil, "overflow do clone vira erro legível")
seen.overflow = false

seen.reply = ""
local fallback_parent = { cfg = parent.cfg, active = parent.active, MAX_ITER = 20,
  agent_id = "main", workspace = "/tmp", msgs = {} }
check(spawn.spawn({ task = "y" }, fallback_parent) == "", "resposta vazia do clone não quebra")

-- Bloco aninhado: 3 linhas visíveis, depois contador de ocultas.
local lines = ui_sub.finish_lines()
check(lines == 0, "sem ferramentas do clone, nenhuma linha extra")
for _ = 1, 5 do ui_sub.child_start("Read | arquivo.lua") end
check(ui_sub.finish_lines() == 4, "5 ferramentas = 3 visíveis + 1 contador")
check(ui_sub.finish_lines() == 0, "contador zera após finish")

local tui = require("ui.tools_init.executor")
local shown = capture(function() tui.tool_end("Subagente | faça X", "RESPOSTA FINAL SECRETA", true) end)
check(not shown:find("RESPOSTA FINAL SECRETA", 1, true), "resposta final do Subagente não aparece na TUI")
local shown_err = capture(function() tui.tool_end("Subagente | faça X", "❌ falha grave\nlinha 2", false) end)
check(shown_err:find("falha grave", 1, true) ~= nil and not shown_err:find("linha 2", 1, true),
  "falha do Subagente mostra só a primeira linha")
local shown_read = capture(function() tui.tool_end("Read | a.lua", "CONTEUDO_NORMAL", true) end)
check(shown_read:find("CONTEUDO_NORMAL", 1, true) ~= nil, "tool comum continua mostrando o corpo")

print(failures == 0 and "\nTODOS OS TESTES PASSARAM" or ("\n" .. failures .. " FALHA(S)"))
os.exit(failures == 0 and 0 or 1)
