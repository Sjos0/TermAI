-- :gate_detector.detect_gates: gates Exec, Read, Edit, Write, FLUSH_DONE e formatos de tool_calls.
local harness = require("tests.helpers.harness")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
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
end

return M
