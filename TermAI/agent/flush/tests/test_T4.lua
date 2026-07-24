-- Test T4: FlushLoop — Validação da lógica do loop próprio do flush (TDD conceitual)
-- Testa as transições de estado e decisões do loop SEM chamar API real.
-- A implementação real substituirá ag_loop.rodar em flush.lua.

-- ==========================================
-- SIMULAÇÃO DO FLUSHLOOP (lógica pura)
-- ==========================================
local M = {}

-- Simula o flush loop work: detect_gates + render_checklist + decisão
-- turnos: tabela de turnos simulados, cada um com tool_calls e resp
-- max_iter: limite máximo de iterações
-- Retorna { done, estado_final, turnos_executados }
function M.simular(turnos, max_iter)
  max_iter = max_iter or 10

  -- Estado inicial (como em T1)
  local fs = { exec = false, read = false, edit = false, done = false }
  function fs.reset()
    fs.exec = false; fs.read = false; fs.edit = false; fs.done = false
  end

  -- detect_gates (mesma lógica de T2)
  local function detect_gates(tool_calls, resp, flush_state, tool_results)
    tool_results = tool_results or {}
    if tool_calls and #tool_calls > 0 then
      for i, tc in ipairs(tool_calls) do
        local func = tc["function"] or tc
        local name = func.name or tc.name
        local args = func.arguments or tc.arguments or ""
        local args_str = type(args) == "string" and args or (type(args) == "table" and (args.file or args.path or "") or "")
        if not flush_state.exec and name == "exec" and (args_str:match("date") or args_str:match("%%Y")) then
          flush_state.exec = true
        end
        if not flush_state.read and name == "Read" and (args_str:match("memory/") or args_str:match("%.md")) then
          flush_state.read = true
        end
        if not flush_state.edit and (name == "Edit" or name == "Write") and (args_str:match("memory/") or args_str:match("%.md")) then
          local result = tool_results[i]
          if result == nil or result == true then flush_state.edit = true end
        end
      end
    end
    if not flush_state.done and resp and resp:match("%[FLUSH_DONE%]") then
      flush_state.done = true
    end
  end

  -- render_checklist (como T3)
  local function render_checklist(fs)
    local x, o = "[x]", "[ ]"
    return string.format("<FLUSH_STATUS>\n  %s exec  %s read  %s edit  %s done\n</FLUSH_STATUS>",
      fs.exec and x or o, fs.read and x or o, fs.edit and x or o, fs.done and x or o)
  end

  local iter = 0
  local gen_turnos = turnos or {}

  while iter < max_iter do
    iter = iter + 1

    -- Pega dados do turno simulado
    local turno = gen_turnos[iter] or { tool_calls = {}, resp = "", tool_results = {} }

    -- Renderiza checklist (o modelo "vê" isso)
    local checklist = render_checklist(fs)

    -- Simula API + tool_runner (dados mock)
    local tool_calls = turno.tool_calls or {}
    local resp = turno.resp or ""
    local tool_results = turno.tool_results or {}

    -- Detecta gates
    detect_gates(tool_calls, resp, fs, tool_results)

    -- Se done, retorna sucesso
    if fs.done then
      return { done = true, estado = fs, iteracoes = iter, checklist = checklist }
    end
  end

  -- MAX_ITER estourado sem done
  return { done = false, estado = fs, iteracoes = iter, checklist = render_checklist(fs) }
end

-- ==========================================
-- TESTES
-- ==========================================
local pass = 0
local fail = 0
local function test(nome, fn)
  local ok, err = pcall(fn)
  if ok then
    pass = pass + 1
    io.write("  ✅ " .. nome .. "\n")
  else
    fail = fail + 1
    io.write("  ❌ " .. nome .. " — " .. tostring(err) .. "\n")
  end
end

-- Teste 1: Caminho feliz completo (4 turnos)
test("Caminho feliz — exec → read → edit → done em 4 turnos", function()
  local turnos = {
    { tool_calls = {{ name = "exec", arguments = "date \"+%Y-%m-%d\"" }}, resp = "", tool_results = {} },
    { tool_calls = {{ name = "Read", arguments = "memory/2026-07-16.md" }}, resp = "", tool_results = {} },
    { tool_calls = {{ name = "Edit", arguments = "memory/2026-07-16.md" }}, resp = "", tool_results = { true } },
    { tool_calls = {}, resp = "[FLUSH_DONE]", tool_results = {} },
  }
  local r = M.simular(turnos, 10)
  assert(r.done == true, "Deveria ter concluido")
  assert(r.iteracoes == 4, "Deveria levar 4 iteracoes, levou " .. r.iteracoes)
end)

-- Teste 2: Falha no Edit → retenta no turno seguinte → conclui
test("Edit falha no turno 3, retenta no 4, conclui no 5", function()
  local turnos = {
    { tool_calls = {{ name = "exec", arguments = "date \"+%Y-%m-%d\"" }}, resp = "" },
    { tool_calls = {{ name = "Read", arguments = "memory/2026-07-16.md" }}, resp = "" },
    { tool_calls = {{ name = "Edit", arguments = "memory/2026-07-16.md" }}, resp = "", tool_results = { false } },
    { tool_calls = {{ name = "Read", arguments = "memory/2026-07-16.md" }}, resp = "" },
    { tool_calls = {{ name = "Edit", arguments = "memory/2026-07-16.md" }}, resp = "", tool_results = { true } },
    { tool_calls = {}, resp = "[FLUSH_DONE]" },
  }
  local r = M.simular(turnos, 10)
  assert(r.done == true, "Deveria ter concluido mesmo com falha no edit")
  assert(r.estado.edit == true, "edit deveria estar true ao final")
end)

-- Teste 3: MAX_ITER estourado sem done → retorna false
test("MAX_ITER=3 estourado sem done -> done=false", function()
  -- Só exec, nunca termina
  local turnos = {
    { tool_calls = {}, resp = "Processando..." },
    { tool_calls = {}, resp = "Ainda processando..." },
    { tool_calls = {}, resp = "Quase la..." },
    { tool_calls = {}, resp = "[FLUSH_DONE]" }, -- não alcança
  }
  local r = M.simular(turnos, 3)
  assert(r.done == false, "MAX_ITER=3 deveria estourar antes de concluir")
  assert(r.iteracoes == 3, "Deveria executar exatas 3 iteracoes")
end)

-- Teste 4: Checklist mostra progresso
test("Checklist mostra progresso correto", function()
  local turno1 = { tool_calls = {{ name = "exec", arguments = "date \"+%Y-%m-%d\"" }}, resp = "" }
  local r1 = M.simular({ turno1 }, 10)
  assert(r1.checklist:match("%[x%] exec"), "exec deveria estar marcado como [x]")
  assert(r1.checklist:match("%[ %] read"), "read deveria estar como [ ]")
  assert(r1.checklist:match("%[ %] edit"), "edit deveria estar como [ ]")
end)

-- Teste 5: Estado não degrada entre turnos
test("Estado preservado entre turnos (exec continua true)", function()
  local turnos = {
    { tool_calls = {{ name = "exec", arguments = "date \"+%Y-%m-%d\"" }}, resp = "" },
    { tool_calls = {}, resp = "pensando..." },
    { tool_calls = {}, resp = "[FLUSH_DONE]" },
  }
  local r = M.simular(turnos, 10)
  assert(r.estado.exec == true, "exec deveria continuar true no final")
end)

-- Teste 6: Ordem não importa (pode fazer read antes de exec)
test("Read antes de exec (ordem flexivel) -> ambos marcados", function()
  local turnos = {
    { tool_calls = {{ name = "Read", arguments = "memory/2026-07-16.md" }}, resp = "" },
    { tool_calls = {{ name = "exec", arguments = "date \"+%Y-%m-%d\"" }}, resp = "" },
    { tool_calls = {}, resp = "[FLUSH_DONE]" },
  }
  local r = M.simular(turnos, 10)
  assert(r.estado.exec == true, "exec true")
  assert(r.estado.read == true, "read true")
  assert(r.done == true, "done true")
end)

-- Teste 7: Sem turnos (0 turnos) → MAX_ITER conta, não done
test("Zero turnos simulados (só respostas vazias) -> done=false", function()
  local r = M.simular({}, 5)
  assert(r.done == false, "Sem turnos com FLUSH_DONE, done=false")
  assert(r.iteracoes == 5, "MAX_ITER=5 executado")
end)

io.write(string.format("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"))
io.write(string.format("✅ T4: FlushLoop (logica) — %d/%d testes passaram\n", pass, pass + fail))
io.write("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

if fail > 0 then os.exit(1) else os.exit(0) end
