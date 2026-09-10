-- tests/flush_units_spec.lua
-- Testes unitários dos submódulos extraídos em agent/flush/
-- Origem: Issue #28 / branch refactor/28-agent-flush-facade
-- Objetivo: trava de regressão para format_context, gate_detector e
--           checklist — módulos de responsabilidade única isoláveis
--           sem I/O de rede nem API.
--
-- "E se isso mudar?": qualquer alteração futura em formatação do
-- contexto de flush, detecção de gates FPM ou render do checklist
-- deve falhar aqui antes de chegar ao loop ReAct.
--
-- Nota: agent/flush/tests/T1|T2|T4 são stubs TDD conceituais que
-- reimplementam a lógica localmente. Este arquivo importa os módulos
-- REAIS e valida o comportamento de produção.

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

print("\n=== Unit tests: agent/flush submodules (Issue #28) ===\n")

-- ─────────────────────────────────────────────────────────────
-- checklist.render_checklist
-- ─────────────────────────────────────────────────────────────
sec("checklist.render_checklist")

local checklist = require("agent.flush.checklist")

local all_false = checklist.render_checklist({
  exec = false, read = false, edit = false, done = false,
})
T("todos false → quatro [ ]",
  all_false:find("%[ %] exec") ~= nil
  and all_false:find("%[ %] read") ~= nil
  and all_false:find("%[ %] edit") ~= nil
  and all_false:find("%[ %] done") ~= nil
  and all_false:find("%[x%]") == nil)

local all_true = checklist.render_checklist({
  exec = true, read = true, edit = true, done = true,
})
T("todos true → quatro [x]",
  all_true:find("%[x%] exec") ~= nil
  and all_true:find("%[x%] read") ~= nil
  and all_true:find("%[x%] edit") ~= nil
  and all_true:find("%[x%] done") ~= nil
  and all_true:find("%[ %]") == nil)

local partial = checklist.render_checklist({
  exec = true, read = false, edit = true, done = false,
})
T("parcial: exec+edit marcados, read+done abertos",
  partial:find("%[x%] exec") ~= nil
  and partial:find("%[ %] read") ~= nil
  and partial:find("%[x%] edit") ~= nil
  and partial:find("%[ %] done") ~= nil)

T("envelope <FLUSH_STATUS>...</FLUSH_STATUS>",
  all_false:match("^<FLUSH_STATUS>") ~= nil
  and all_false:match("</FLUSH_STATUS>$") ~= nil)

-- Contrato de escape do monólito (main): \\n literal, NÃO newline 0x0A.
-- Regressão residual PR #39 / análise Caçador — trava permanente.
local expected_all_false =
  "<FLUSH_STATUS>\\n  [ ] exec  [ ] read  [ ] edit  [ ] done\\n</FLUSH_STATUS>"
T("escape idêntico ao monólito (\\n literal, não 0x0A)",
  all_false == expected_all_false,
  "got=" .. string.format("%q", all_false))

T("não contém newline real (0x0A) no corpo",
  all_false:find("\n", 1, true) == nil)

T("contém o par de caracteres backslash+n",
  all_false:find("\\n", 1, true) ~= nil)

-- ─────────────────────────────────────────────────────────────
-- format_context.format_context
-- ─────────────────────────────────────────────────────────────
sec("format_context.format_context")

local fc = require("agent.flush.format_context")

T("msgs vazia → mensagem padrão",
  fc.format_context({}) == "[Nenhuma mensagem nova desde o último Flush]")

local only_system = fc.format_context({
  { role = "system", content = "ignorar" },
})
T("só system → contexto sem mensagens relevantes",
  only_system == "[Contexto sem mensagens relevantes]")

local user_asst = fc.format_context({
  { role = "user", content = "olá mundo" },
  { role = "assistant", content = "resposta" },
})
T("user+assistant → labels USUÁRIO e AGENTE",
  user_asst:find("%[USUÁRIO%]") ~= nil
  and user_asst:find("%[AGENTE%]") ~= nil
  and user_asst:find("olá mundo") ~= nil
  and user_asst:find("resposta") ~= nil)

T("separador ─ entre mensagens",
  user_asst:find(string.rep("─", 30)) ~= nil)

local with_tools = fc.format_context({
  {
    role = "assistant",
    content = "antes <tool>call</tool> meio <tool_result id=\"1\">ok</tool_result> depois",
  },
})
T("strip <tool> e <tool_result>",
  with_tools:find("<tool>") == nil
  and with_tools:find("<tool_result") == nil
  and with_tools:find("antes") ~= nil
  and with_tools:find("depois") ~= nil)

local long = string.rep("x", 1600)
local truncated = fc.format_context({
  { role = "user", content = long },
})
T("trunca conteúdo >1500 chars",
  truncated:find("… %[truncado%]") ~= nil
  and #truncated < 1600 + 50)

local blank = fc.format_context({
  { role = "user", content = "   \n\t  " },
  { role = "assistant", content = "ok" },
})
T("conteúdo só whitespace é ignorado",
  blank:find("%[USUÁRIO%]") == nil
  and blank:find("%[AGENTE%]") ~= nil
  and blank:find("ok") ~= nil)

local nil_content = fc.format_context({
  { role = "user", content = nil },
})
T("content nil não explode (vira string vazia / ignorado)",
  type(nil_content) == "string")

-- ─────────────────────────────────────────────────────────────
-- gate_detector.detect_gates
-- ─────────────────────────────────────────────────────────────
sec("gate_detector.detect_gates")

local gd = require("agent.flush.gate_detector")

local function fresh()
  return { exec = false, read = false, edit = false, done = false }
end

-- Gate exec: nome de produção é "Exec" (capital E)
local s = fresh()
gd.detect_gates({{ name = "Exec", arguments = 'date "+%Y-%m-%d"' }}, "", s)
T("Exec + date → exec=true",
  s.exec == true and s.read == false and s.edit == false and s.done == false)

s = fresh()
gd.detect_gates({{ name = "Exec", arguments = "date '+%Y-%m-%d %A'" }}, "", s)
T("Exec + %Y → exec=true", s.exec == true)

s = fresh()
gd.detect_gates({{ name = "Exec", arguments = "ls -la" }}, "", s)
T("Exec SEM date/%Y → exec permanece false", s.exec == false)

-- Case sensitivity: stubs T2 usavam "exec" minúsculo; produção usa "Exec"
s = fresh()
gd.detect_gates({{ name = "exec", arguments = 'date "+%Y-%m-%d"' }}, "", s)
T("exec minúsculo NÃO marca (contrato real é 'Exec')",
  s.exec == false,
  "se este teste falhar, produção aceitou 'exec' minúsculo — alinhar contrato")

-- Gate read
s = fresh()
gd.detect_gates({{ name = "Read", arguments = "memory/2026-07-16.md" }}, "", s)
T("Read + memory/ → read=true",
  s.read == true and s.exec == false)

s = fresh()
gd.detect_gates({{ name = "Read", arguments = "notas.md" }}, "", s)
T("Read + .md → read=true", s.read == true)

s = fresh()
gd.detect_gates({{ name = "Read", arguments = "config.json" }}, "", s)
T("Read SEM memory/.md → read false", s.read == false)

-- Gate edit / Write
s = fresh()
gd.detect_gates({{ name = "Edit", arguments = "memory/2026-07-16.md" }}, "", s, { true })
T("Edit memory/ + result true → edit=true", s.edit == true)

s = fresh()
gd.detect_gates({{ name = "Edit", arguments = "memory/2026-07-16.md" }}, "", s, { false })
T("Edit memory/ + result false → edit false", s.edit == false)

s = fresh()
gd.detect_gates({{ name = "Edit", arguments = "memory/x.md" }}, "", s, { "Sucesso ao gravar" })
T("Edit + result string com 'Sucesso' → edit=true", s.edit == true)

s = fresh()
gd.detect_gates({{ name = "Edit", arguments = "memory/x.md" }}, "", s, nil)
T("Edit memory/ + tool_results nil → edit=true (default permissivo)", s.edit == true)

s = fresh()
gd.detect_gates({{ name = "Write", arguments = "memory/2026-07-16.md" }}, "", s, { true })
T("Write memory/ + success → edit=true", s.edit == true)

s = fresh()
gd.detect_gates({{ name = "Edit", arguments = "config.json" }}, "", s, { true })
T("Edit SEM memory/.md → edit false", s.edit == false)

-- Gate done
s = fresh()
gd.detect_gates({}, "Resumo concluído. [FLUSH_DONE]", s)
T("resp com [FLUSH_DONE] → done=true", s.done == true)

s = fresh()
gd.detect_gates({}, "Resumo concluído. Fim.", s)
T("resp SEM [FLUSH_DONE] → done false", s.done == false)

s = fresh()
gd.detect_gates({}, nil, s)
T("resp nil → done false", s.done == false)

-- Formato OpenAI-style { function = { name, arguments } }
s = fresh()
gd.detect_gates({
  { ["function"] = { name = "Read", arguments = "memory/hoje.md" } },
}, "", s)
T("formato function.name + arguments string → read=true", s.read == true)

s = fresh()
gd.detect_gates({
  { ["function"] = { name = "Read" }, arguments = { file = "memory/hoje.md" } },
}, "", s)
T("arguments table com file= → read=true", s.read == true)

s = fresh()
gd.detect_gates({
  { ["function"] = { name = "Read" }, arguments = { path = "notas.md" } },
}, "", s)
T("arguments table com path= → read=true", s.read == true)

-- Múltiplos gates no mesmo turno
s = fresh()
gd.detect_gates({
  { name = "Exec", arguments = 'date "+%Y-%m-%d"' },
  { name = "Read", arguments = "memory/2026-07-16.md" },
}, "", s)
T("múltiplos gates no mesmo turno",
  s.exec == true and s.read == true and s.edit == false and s.done == false)

-- Não rebaixa flags já true
s = { exec = true, read = true, edit = true, done = true }
gd.detect_gates({}, "sem done tag", s)
T("já-true não é rebaixado por turno sem gates",
  s.exec == true and s.read == true and s.edit == true and s.done == true)

-- tool_calls vazio / nil
s = fresh()
gd.detect_gates({}, "", s)
T("tool_calls vazio → nenhum gate", s.exec == false and s.read == false)

s = fresh()
gd.detect_gates(nil, "", s)
T("tool_calls nil → nenhum gate", s.exec == false and s.read == false)

-- ─────────────────────────────────────────────────────────────
-- RELATÓRIO
-- ─────────────────────────────────────────────────────────────
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes unitários dos submódulos flush passaram")
end
