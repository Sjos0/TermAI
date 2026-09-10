-- tests/loop_units_spec.lua
-- Testes dos submódulos extraídos em agent/loop/
-- Origem: Issue #29 / PR #40 (branch refactor/29-agent-loop-facade)
-- Objetivo: trava de regressão para response_utils, system_messages,
--           json_path e xml_path — protocolo do loop ReAct isolável
--           sem API real nem I/O de rede.
--
-- "E se isso mudar?": qualquer alteração em strip de FLUSH_DONE,
-- detecção de intent não cumprido, injeções de boot/restart/cancel,
-- cancelamento atômico JSON, retries vazio/unfulfilled XML ou no
-- contrato {action=return|continue|retry} deve falhar aqui antes
-- de chegar à fachada M.rodar.
--
-- Tipos cobertos:
--   * unitário puro (response_utils)
--   * unitário com doubles (system_messages, json_path, xml_path)
--   * caso extremo (nil, vazio, bordas de retry, prefixos de erro)
--   * contrato estrutural das actions devolvidas aos paths
--   * regressão de comportamento do monólito (Issue #29)

package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

-- Silencia io.write/io.flush dos auto-retries durante os testes
local _io_write, _io_flush = io.write, io.flush
io.write = function() end
io.flush = function() end

print("\n=== Unit tests: agent/loop submodules (Issue #29 / PR #40) ===\n")

-- ═══════════════════════════════════════════════════════════════
-- response_utils — 100% puro, sem doubles
-- ═══════════════════════════════════════════════════════════════
sec("response_utils.strip_flush_tag")

local ru = require("agent.loop.response_utils")

T("nil → string vazia", ru.strip_flush_tag(nil) == "")
T("string vazia → vazia", ru.strip_flush_tag("") == "")
T("só [FLUSH_DONE] → vazia", ru.strip_flush_tag("[FLUSH_DONE]") == "")
T("texto + tag → texto limpo",
  ru.strip_flush_tag("olá [FLUSH_DONE] mundo") == "olá  mundo"
  or ru.strip_flush_tag("olá [FLUSH_DONE] mundo") == "olá mundo")
-- gsub remove a tag; espaços internos ficam; trim só nas bordas
local mid = ru.strip_flush_tag("olá [FLUSH_DONE] mundo")
T("remove tag mantendo texto ao redor", mid:find("olá") ~= nil and mid:find("mundo") ~= nil and mid:find("FLUSH_DONE") == nil)
T("trim bordas",
  ru.strip_flush_tag("  hello  ") == "hello")
T("tag no início",
  ru.strip_flush_tag("[FLUSH_DONE] pronto") == "pronto")
T("tag no fim",
  ru.strip_flush_tag("pronto [FLUSH_DONE]") == "pronto")
T("múltiplas tags",
  ru.strip_flush_tag("[FLUSH_DONE] a [FLUSH_DONE] b") == "a  b"
  or (ru.strip_flush_tag("[FLUSH_DONE] a [FLUSH_DONE] b"):find("a") ~= nil
      and ru.strip_flush_tag("[FLUSH_DONE] a [FLUSH_DONE] b"):find("FLUSH") == nil))
T("não confunde tag parecida",
  ru.strip_flush_tag("[FLUSH_DONE_NOT]") == "[FLUSH_DONE_NOT]")

sec("response_utils.is_unfulfilled_intent")

T("nil → false", ru.is_unfulfilled_intent(nil) == false)
T("vazio → false", ru.is_unfulfilled_intent("") == false)
T("termina em : → true", ru.is_unfulfilled_intent("Vou ler o arquivo:") == true)
T("só : → true", ru.is_unfulfilled_intent(":") == true)
T("espaços após : são trimados → true",
  ru.is_unfulfilled_intent("ação:   ") == true)
T("texto normal → false", ru.is_unfulfilled_intent("Resposta completa.") == false)
T("termina em ? → false", ru.is_unfulfilled_intent("Posso ajudar?") == false)
T("whitespace puro → false",
  ru.is_unfulfilled_intent("   \n\t  ") == false)
T(": no meio → false", ru.is_unfulfilled_intent("a:b") == false)

-- ═══════════════════════════════════════════════════════════════
-- Doubles compartilhados
-- ═══════════════════════════════════════════════════════════════
local ui_log = {}
local function reset_ui_log() ui_log = {} end
package.loaded["ui"] = {
  start_thinking = function(label)
    ui_log[#ui_log + 1] = { op = "start_thinking", label = label }
  end,
  update_label = function()
    ui_log[#ui_log + 1] = { op = "update_label" }
  end,
  ai_msg_stream = function(text)
    ui_log[#ui_log + 1] = { op = "ai_msg_stream", text = text }
  end,
  agent_limit = function() end,
  stop_thinking = function() return 0.1 end,
}

local batch_log = {}
package.loaded["agent.loop.tool_runner"] = {
  run_batch = function(ctx, tool_calls)
    batch_log[#batch_log + 1] = { ctx = ctx, tool_calls = tool_calls }
    -- simula cancelamento se a flag já estiver no ctx antes — o path
    -- verifica DEPOIS de run_batch; testes setam a flag no próprio run_batch
  end,
}

local th_state = {
  texto = "",
  ferramentas = {},
  pre_feedback = nil,
  exec_result = "",
}
package.loaded["agent.tools_handler"] = {
  parsear = function(resp)
    return th_state.texto, th_state.ferramentas, th_state.pre_feedback
  end,
  executar = function(ferramentas)
    return th_state.exec_result
  end,
}

-- memory mock controlável (recarregado com system_messages)
local mem_state = {
  available = false,
  result = nil,
  should_error = false,
}
package.preload["tools.memory"] = function()
  if not mem_state.available then
    error("memory not available")
  end
  return {
    search = function(q)
      if mem_state.should_error then error("search failed") end
      return mem_state.result
    end,
  }
end

local function reload_system_messages()
  package.loaded["agent.loop.system_messages"] = nil
  package.loaded["tools.memory"] = nil
  -- força reavaliação do _mem via preload
  return require("agent.loop.system_messages")
end

-- ═══════════════════════════════════════════════════════════════
-- system_messages.prepare_user_turn
-- ═══════════════════════════════════════════════════════════════
sec("system_messages.prepare_user_turn — role / no-op")

mem_state.available = false
local sm = reload_system_messages()

local ctx_noop = { msgs = { { role = "system" } }, last_tool_sig = "x" }
local out, spin = sm.prepare_user_turn(ctx_noop, "texto", "assistant")
T("role != user → texto intacto", out == "texto")
T("role != user → spinner false", spin == false)
T("role != user → last_tool_sig NÃO limpo", ctx_noop.last_tool_sig == "x")

sec("system_messages — boot login vs restart")

-- login: first turn + msgs <= 1
mem_state.available = false
sm = reload_system_messages()
local ctx_login = { msgs = { { role = "system" } }, last_tool_sig = "sig" }
out, spin = sm.prepare_user_turn(ctx_login, "oi", "user")
T("login: last_tool_sig limpo", ctx_login.last_tool_sig == nil)
T("login: injeta User has joined",
  type(out) == "string" and out:find("User has joined the session") ~= nil)
T("login: preserva texto do user", out:find("oi") ~= nil)
T("login: sem memória → spinner false", spin == false)

-- segundo turno na mesma sessão: NÃO reinsere boot
out = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "segundo", "user")
T("segundo turno: sem nova system message de boot",
  out:find("SYSTEM MESSAGE: User has joined") == nil
  and out:find("System has restarted") == nil)
T("segundo turno: texto puro", out == "segundo")

-- restart: first turn + msgs > 1
sm = reload_system_messages()
local ctx_restart = {
  msgs = {
    { role = "system" },
    { role = "user" },
    { role = "assistant" },
  },
}
out = sm.prepare_user_turn(ctx_restart, "continua", "user")
T("restart: injeta System has restarted",
  out:find("System has restarted") ~= nil)
T("restart: preserva texto", out:find("continua") ~= nil)

sec("system_messages — cancelamento prévio")

sm = reload_system_messages()
-- consome first-turn boot
sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")

local ctx_cancel = {
  msgs = { { role = "system" } },
  prev_command_cancelled = true,
}
out = sm.prepare_user_turn(ctx_cancel, "novo plano", "user")
T("cancel: injeta CANCELLED",
  out:find("CANCELLED by the user") ~= nil)
T("cancel: flag consumida (nil)", ctx_cancel.prev_command_cancelled == nil)
T("cancel: preserva texto do user", out:find("novo plano") ~= nil)

-- cancel + boot no mesmo primeiro turno
sm = reload_system_messages()
local ctx_both = {
  msgs = { { role = "system" } },
  prev_command_cancelled = true,
}
out = sm.prepare_user_turn(ctx_both, "hi", "user")
T("boot+cancel: ambas injeções presentes",
  out:find("User has joined") ~= nil and out:find("CANCELLED") ~= nil)

sec("system_messages — injeção de memória")

mem_state.available = true
mem_state.should_error = false
mem_state.result = "fato importante da sessão"
sm = reload_system_messages()
-- consome boot
sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
reset_ui_log()
out, spin = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "pergunta longa o bastante", "user")
T("mem hit: spinner true", spin == true)
T("mem hit: prefixo MEMÓRIA RELEVANTE",
  out:find("MEMÓRIA RELEVANTE") ~= nil)
T("mem hit: conteúdo injetado", out:find("fato importante") ~= nil)
T("mem hit: pergunta preservada", out:find("pergunta longa") ~= nil)
T("mem hit: start_thinking Injetando",
  #ui_log >= 1 and ui_log[1].op == "start_thinking" and ui_log[1].label == "Injetando")
T("mem hit: update_label chamado",
  (function()
    for _, e in ipairs(ui_log) do if e.op == "update_label" then return true end end
    return false
  end)())

-- prefixos que DEVEM ser ignorados
local reject_prefixes = { "❌ erro", "📭 vazio", "🔍 Nenhuma memória" }
for _, prefix in ipairs(reject_prefixes) do
  mem_state.result = prefix .. " resto"
  sm = reload_system_messages()
  sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
  out = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "pergunta longa o bastante", "user")
  T("mem rejeita prefixo '" .. prefix:sub(1, 2) .. "...'",
    out:find("MEMÓRIA RELEVANTE") == nil)
end

-- search lança erro → pcall engole, sem injeção
mem_state.should_error = true
mem_state.result = "ignorar"
sm = reload_system_messages()
sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
out, spin = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "pergunta longa o bastante", "user")
T("mem search error: spinner ainda true (start_thinking rodou)", spin == true)
T("mem search error: sem injeção", out:find("MEMÓRIA RELEVANTE") == nil)

-- cur_text curto demais (# <= 2) → não busca memória
mem_state.should_error = false
mem_state.result = "não deve aparecer"
sm = reload_system_messages()
sm.prepare_user_turn({ msgs = { { role = "system" } } }, "boot", "user")
-- após boot, texto "ab" tem len 2 — condição é #cur_text > 2
out, spin = sm.prepare_user_turn({ msgs = { { role = "system" } } }, "ab", "user")
T("mem cur_text len<=2: sem busca/spinner", spin == false and out == "ab")

-- ═══════════════════════════════════════════════════════════════
-- json_path.handle
-- ═══════════════════════════════════════════════════════════════
sec("json_path.handle")

-- Garante response_utils real; json_path ainda não carregado ou recarrega
package.loaded["agent.loop.json_path"] = nil
local jp = require("agent.loop.json_path")

local function fresh_ctx(flags)
  flags = flags or {}
  return {
    tool_cancelled = flags.tool_cancelled,
    prev_command_cancelled = flags.prev_command_cancelled,
  }
end

-- continue feliz
reset_ui_log()
batch_log = {}
local ctx = fresh_ctx()
local r = jp.handle(ctx, "vou executar", { { name = "Exec" } }, true, 1.5)
T("json continue: action=continue", r.action == "continue")
T("json continue: iter_delta=1", r.iter_delta == 1)
T("json continue: cur_text nil", r.cur_text == nil)
T("json continue: cur_role nil", r.cur_role == nil)
T("json continue: last_reasoning vazio", r.last_reasoning == "")
T("json continue: streamou texto",
  #ui_log == 1 and ui_log[1].op == "ai_msg_stream" and ui_log[1].text == "vou executar")
T("json continue: run_batch chamado", #batch_log == 1)

-- resp só com FLUSH_DONE → strip vazio → não streama, mas retorna flush_done
reset_ui_log()
batch_log = {}
r = jp.handle(fresh_ctx(), "[FLUSH_DONE]", { { name = "X" } }, true, 0.2)
T("json FLUSH_DONE puro: action=return", r.action == "return")
T("json FLUSH_DONE puro: flush_done=true", r.flush_done == true)
T("json FLUSH_DONE puro: não streama vazio", #ui_log == 0)
T("json FLUSH_DONE puro: is_overflow=false", r.is_overflow == false)
T("json FLUSH_DONE puro: propaga elapsed", r.elapsed == 0.2)
T("json FLUSH_DONE puro: propaga stream_complete", r.stream_complete == true)

-- texto + FLUSH_DONE → streama stripped e return flush_done
reset_ui_log()
r = jp.handle(fresh_ctx(), "arquivo salvo [FLUSH_DONE]", { { name = "Write" } }, false, 3)
T("json FLUSH_DONE+texto: return+flush_done", r.action == "return" and r.flush_done == true)
T("json FLUSH_DONE+texto: streamou sem tag",
  #ui_log == 1 and ui_log[1].text:find("FLUSH_DONE") == nil and ui_log[1].text:find("arquivo salvo") ~= nil)
T("json FLUSH_DONE+texto: stream_complete propagado", r.stream_complete == false)

-- cancelamento atômico: flag setada ANTES de handle; run_batch no mock não mexe
-- Na produção, tool_runner seta ctx.tool_cancelled durante run_batch.
-- Simulamos isso com um run_batch que seta a flag:
package.loaded["agent.loop.tool_runner"].run_batch = function(c, tc)
  batch_log[#batch_log + 1] = { ctx = c, tool_calls = tc }
  c.tool_cancelled = true
end
package.loaded["agent.loop.json_path"] = nil
jp = require("agent.loop.json_path")

ctx = fresh_ctx()
r = jp.handle(ctx, "rodando", { { name = "Exec" } }, true, 9)
T("json cancel: action=return", r.action == "return")
T("json cancel: flush_done=false", r.flush_done == false)
T("json cancel: tool_cancelled consumido", ctx.tool_cancelled == nil)
T("json cancel: prev_command_cancelled=true", ctx.prev_command_cancelled == true)
T("json cancel: resp original preservado", r.resp == "rodando")
T("json cancel: last_reasoning vazio", r.last_reasoning == "")

-- cancel tem prioridade sobre FLUSH_DONE (verificado primeiro no código)
ctx = fresh_ctx()
r = jp.handle(ctx, "done [FLUSH_DONE]", { { name = "X" } }, true, 1)
T("json cancel>FLUSH_DONE: flush_done=false (cancel vence)", r.flush_done == false)
T("json cancel>FLUSH_DONE: action=return", r.action == "return")

-- restaura run_batch neutro
package.loaded["agent.loop.tool_runner"].run_batch = function(c, tc)
  batch_log[#batch_log + 1] = { ctx = c, tool_calls = tc }
end
package.loaded["agent.loop.json_path"] = nil
jp = require("agent.loop.json_path")

-- contrato: continue NÃO deve ter campos de return espalhados de forma ambígua
r = jp.handle(fresh_ctx(), "ok", { { name = "A" } }, true, 0)
T("json continue contrato: sem flush_done", r.flush_done == nil)
T("json continue contrato: sem is_overflow", r.is_overflow == nil)

-- ═══════════════════════════════════════════════════════════════
-- xml_path.handle
-- ═══════════════════════════════════════════════════════════════
sec("xml_path.handle")

package.loaded["agent.loop.xml_path"] = nil
local xp = require("agent.loop.xml_path")

local function set_th(texto, ferramentas, pre_feedback, exec_result)
  th_state.texto = texto or ""
  th_state.ferramentas = ferramentas or {}
  th_state.pre_feedback = pre_feedback
  th_state.exec_result = exec_result or ""
end

-- resposta final normal
reset_ui_log()
set_th("resposta final do agente", {}, nil, "")
r = xp.handle({}, "resposta final do agente", "raciocínio", true, 2.0, 0, 2)
T("xml final: action=return", r.action == "return")
T("xml final: flush_done=false", r.flush_done == false)
T("xml final: last_reasoning propagado", r.last_reasoning == "raciocínio")
T("xml final: streamou display",
  #ui_log == 1 and ui_log[1].text == "resposta final do agente")
T("xml final: elapsed propagado", r.elapsed == 2.0)

-- resposta final com FLUSH_DONE (sem tools)
reset_ui_log()
set_th("arquivado [FLUSH_DONE]", {}, nil, "")
r = xp.handle({}, "arquivado [FLUSH_DONE]", nil, true, 1, 0, 2)
T("xml FLUSH_DONE sem tools: return+flush_done",
  r.action == "return" and r.flush_done == true)
T("xml FLUSH_DONE sem tools: streamou sem tag",
  #ui_log == 1 and ui_log[1].text:find("FLUSH_DONE") == nil)
T("xml FLUSH_DONE sem tools: last_reasoning vazio (nil→\"\")",
  r.last_reasoning == "")

-- tools XML → continue
reset_ui_log()
set_th("usando ferramenta", { { name = "Read" } }, nil, "resultado-tool")
r = xp.handle({}, "usando ferramenta", "", true, 0.5, 0, 2)
T("xml tools: action=continue", r.action == "continue")
T("xml tools: iter_delta=1", r.iter_delta == 1)
T("xml tools: cur_text=exec_result", r.cur_text == "resultado-tool")
T("xml tools: cur_role=user", r.cur_role == "user")
T("xml tools: streamou texto", #ui_log == 1 and ui_log[1].text == "usando ferramenta")

-- pre_feedback sem tools → continue com iter_delta=0
set_th("", {}, "feedback prévio", "")
r = xp.handle({}, "", "", true, 0, 0, 2)
T("xml pre_feedback only: continue", r.action == "continue")
T("xml pre_feedback only: iter_delta=0", r.iter_delta == 0)
T("xml pre_feedback only: cur_text=feedback", r.cur_text == "feedback prévio")

-- tools + pre_feedback → concatena com \n\n
set_th("txt", { { name = "X" } }, "mais feedback", "out")
r = xp.handle({}, "txt", "", true, 0, 0, 2)
T("xml tools+feedback: cur_text concatenado",
  r.cur_text == "out\n\nmais feedback")

-- tools + FLUSH_DONE → return flush_done (não continue)
set_th("ok [FLUSH_DONE]", { { name = "W" } }, nil, "wrote")
r = xp.handle({}, "raw [FLUSH_DONE]", "", true, 0, 0, 2)
T("xml tools+FLUSH_DONE: return flush_done",
  r.action == "return" and r.flush_done == true)

-- retry: resposta vazia
reset_ui_log()
set_th("", {}, nil, "")
r = xp.handle({}, "", nil, true, 0, 0, 2)
T("xml vazio: action=retry", r.action == "retry")
T("xml vazio: vazio_count=1", r.vazio_count == 1)
T("xml vazio: cur_role=user", r.cur_role == "user")
T("xml vazio sem reasoning: mensagem genérica",
  r.cur_text:find("Continue de onde parou") ~= nil)

-- retry: vazio COM reasoning
set_th("[vazio]", {}, nil, "")
r = xp.handle({}, "[vazio]", "estava pensando em X", true, 0, 0, 2)
T("xml [vazio]+reasoning: mensagem de raciocínio",
  r.action == "retry" and r.cur_text:find("não emitiu resposta") ~= nil)

-- retry: unfulfilled intent
reset_ui_log()
set_th("Vou abrir o arquivo:", {}, nil, "")
r = xp.handle({}, "Vou abrir o arquivo:", "", true, 0, 0, 2)
T("xml unfulfilled: action=retry", r.action == "retry")
T("xml unfulfilled: mensagem anúncio",
  r.cur_text:find("anunciou uma ação") ~= nil)
T("xml unfulfilled: streamou o anúncio",
  #ui_log == 1 and ui_log[1].text == "Vou abrir o arquivo:")

-- esgota retries (vazio_count já no limite)
reset_ui_log()
set_th("", {}, nil, "")
r = xp.handle({}, "", "", true, 0, 2, 2)
T("xml retries esgotados: action=return", r.action == "return")
T("xml retries esgotados: flush_done=false", r.flush_done == false)

-- unfulfilled no limite também retorna
set_th("fazendo:", {}, nil, "")
r = xp.handle({}, "fazendo:", "", true, 0, 2, 2)
T("xml unfulfilled esgotado: return", r.action == "return")
T("xml unfulfilled esgotado: streamou display",
  #ui_log >= 1 and ui_log[#ui_log].text == "fazendo:")

-- [ERRO...] não entra em retry de vazio
set_th("", {}, nil, "")
r = xp.handle({}, "[ERRO provider down]", "", true, 0, 0, 2)
T("xml [ERRO]: não é retry (return)", r.action == "return")

-- [ERRO] com texto unfulfilled também não retenta
set_th("vou:", {}, nil, "")
r = xp.handle({}, "[ERRO algo] vou:", "", true, 0, 0, 2)
T("xml [ERRO]+unfulfilled: return (sem retry)", r.action == "return")

-- FLUSH_DONE na resp impede classificar como vazio mesmo com display vazio
-- (strip remove a tag do texto; resp bruta ainda tem a tag)
set_th("[FLUSH_DONE]", {}, nil, "")
r = xp.handle({}, "[FLUSH_DONE]", "", true, 0, 0, 2)
T("xml resp FLUSH_DONE display vazio: return flush_done",
  r.action == "return" and r.flush_done == true)

-- contrato estrutural das actions
set_th("ok", {}, nil, "")
r = xp.handle({}, "ok", "rr", true, 1, 0, 2)
T("xml return contrato: campos obrigatórios",
  r.action == "return"
  and r.resp ~= nil
  and r.elapsed ~= nil
  and r.flush_done ~= nil
  and r.is_overflow == false
  and r.stream_complete ~= nil
  and r.last_reasoning ~= nil)

set_th("t", { { name = "A" } }, nil, "x")
r = xp.handle({}, "t", "", true, 0, 0, 2)
T("xml continue contrato: campos obrigatórios",
  r.action == "continue"
  and r.iter_delta ~= nil
  and r.cur_text ~= nil
  and r.cur_role == "user"
  and r.last_reasoning == "")

set_th("", {}, nil, "")
r = xp.handle({}, "", "", true, 0, 0, 2)
T("xml retry contrato: campos obrigatórios",
  r.action == "retry"
  and type(r.vazio_count) == "number"
  and r.cur_text ~= nil
  and r.cur_role == "user")

-- ═══════════════════════════════════════════════════════════════
-- Integração leve: response_utils ↔ paths (sem fachada)
-- ═══════════════════════════════════════════════════════════════
sec("integração leve response_utils ↔ paths")

-- json_path usa strip antes de streamar
reset_ui_log()
package.loaded["agent.loop.tool_runner"].run_batch = function() end
package.loaded["agent.loop.json_path"] = nil
jp = require("agent.loop.json_path")
jp.handle({}, "msg [FLUSH_DONE]", { { name = "Z" } }, true, 0)
T("integração json: stream recebe texto já stripped",
  #ui_log == 1 and ui_log[1].text:find("FLUSH_DONE") == nil and ui_log[1].text:find("msg") ~= nil)

-- xml_path classifica unfulfilled via response_utils
set_th("Próximo passo:", {}, nil, "")
package.loaded["agent.loop.xml_path"] = nil
xp = require("agent.loop.xml_path")
r = xp.handle({}, "Próximo passo:", "", true, 0, 0, 1)
T("integração xml: unfulfilled detectado via response_utils",
  r.action == "retry" and r.cur_text:find("anunciou uma ação") ~= nil)

-- ═══════════════════════════════════════════════════════════════
-- RELATÓRIO
-- ═══════════════════════════════════════════════════════════════
io.write = _io_write
io.flush = _io_flush

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes dos submódulos agent/loop passaram")
end
