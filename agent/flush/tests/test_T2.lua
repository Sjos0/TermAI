-- Test T2: GateDetector — Inspeção de tool_calls e resposta (TDD isolado)
-- Testa a lógica de detecção com tool_calls mock.
-- NÃO carrega agent.flush (depende de API real).

local M = {}

-- Função a ser implementada em flush.lua
-- tool_calls: array de tool calls do modelo
-- resp: texto da resposta do modelo
-- flush_state: tabela com 4 campos booleanos
-- tool_results: (opcional) tabela com resultados das tools
function M.detect_gates(tool_calls, resp, flush_state, tool_results)
  tool_results = tool_results or {}

  if tool_calls and #tool_calls > 0 then
    for i, tc in ipairs(tool_calls) do
      local func = tc["function"] or tc
      local name = func.name or tc.name
      local args = func.arguments or tc.arguments or ""
      local args_str = type(args) == "string" and args or (type(args) == "table" and (args.file or args.path or "") or "")

      -- Gate exec: date
      if not flush_state.exec then
        if name == "exec" and (args_str:match("date") or args_str:match("%%Y") or args_str:match("%%A")) then
          flush_state.exec = true
        end
      end

      -- Gate read: memory/*.md
      if not flush_state.read then
        if name == "Read" and (args_str:match("memory/") or args_str:match("%.md")) then
          flush_state.read = true
        end
      end

      -- Gate edit: Edit/Write memory/*.md com sucesso
      if not flush_state.edit then
        if (name == "Edit" or name == "Write") and (args_str:match("memory/") or args_str:match("%.md")) then
          local result = tool_results[i]
          if result == nil or result == true or (type(result) == "string" and result:match("Sucesso")) then
            flush_state.edit = true
          end
        end
      end
    end
  end

  -- Gate done: FLUSH_DONE na resposta
  if not flush_state.done and resp and resp:match("%[FLUSH_DONE%]") then
    flush_state.done = true
  end
end

-- ==========================================
-- TESTES
-- ==========================================
local function reset_state()
  return { exec = false, read = false, edit = false, done = false }
end

local pass = 0
local fail = 0
local function test(nome, fn)
  local state = reset_state()
  local ok, err = pcall(function() fn(state) end)
  if ok then
    pass = pass + 1
    io.write("  ✅ " .. nome .. "\n")
  else
    fail = fail + 1
    io.write("  ❌ " .. nome .. " — " .. tostring(err) .. "\n")
  end
end

test("Gate exec com 'date'", function(s)
  M.detect_gates({{ name = "exec", arguments = "date \"+%Y-%m-%d\"" }}, "", s)
  assert(s.exec == true, "exec deveria ser true")
  assert(s.read == false and s.edit == false and s.done == false)
end)

test("Gate exec com %%Y (alternativo)", function(s)
  M.detect_gates({{ name = "exec", arguments = "date '+%%Y-%%m-%%d %%A'" }}, "", s)
  assert(s.exec == true)
end)

test("Gate exec SEM date (nao marca)", function(s)
  M.detect_gates({{ name = "exec", arguments = "ls -la" }}, "", s)
  assert(s.exec == false)
end)

test("Gate Read com memory/", function(s)
  M.detect_gates({{ name = "Read", arguments = "memory/2026-07-16.md" }}, "", s)
  assert(s.read == true)
  assert(s.exec == false and s.edit == false and s.done == false)
end)

test("Gate Read com .md", function(s)
  M.detect_gates({{ name = "Read", arguments = "teste.md" }}, "", s)
  assert(s.read == true)
end)

test("Gate Read SEM .md (nao marca)", function(s)
  M.detect_gates({{ name = "Read", arguments = "config.json" }}, "", s)
  assert(s.read == false)
end)

test("Gate Edit memory/ com sucesso", function(s)
  M.detect_gates({{ name = "Edit", arguments = "memory/2026-07-16.md" }}, "", s, { true })
  assert(s.edit == true)
end)

test("Gate Edit SEM sucesso (nao marca)", function(s)
  M.detect_gates({{ name = "Edit", arguments = "memory/2026-07-16.md" }}, "", s, { false })
  assert(s.edit == false)
end)

test("Gate Write memory/ com sucesso", function(s)
  M.detect_gates({{ name = "Write", arguments = "memory/2026-07-16.md" }}, "", s, { true })
  assert(s.edit == true)
end)

test("Gate done com FLUSH_DONE", function(s)
  M.detect_gates({}, "Resumo concluido. [FLUSH_DONE]", s)
  assert(s.done == true)
end)

test("Gate done SEM FLUSH_DONE (nao marca)", function(s)
  M.detect_gates({}, "Resumo concluido. Fim.", s)
  assert(s.done == false)
end)

test("Multiplos gates no mesmo turno", function(s)
  M.detect_gates({
    { name = "exec", arguments = "date \"+%Y-%m-%d\"" },
    { name = "Read", arguments = "memory/2026-07-16.md" },
  }, "", s)
  assert(s.exec == true)
  assert(s.read == true)
  assert(s.edit == false)
  assert(s.done == false)
end)

test("tool_calls vazio (nenhum gate)", function(s)
  M.detect_gates({}, "", s)
  assert(s.exec == false and s.read == false and s.edit == false and s.done == false)
end)

test("Edit SEM memory/ (nao marca)", function(s)
  M.detect_gates({{ name = "Edit", arguments = "config.json" }}, "", s, { true })
  assert(s.edit == false)
end)

test("Argumento como tabela JSON", function(s)
  M.detect_gates({
    { ["function"] = { name = "Read" }, arguments = { file = "memory/2026-07-16.md" } }
  }, "", s)
  assert(s.read == true)
end)

io.write(string.format("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"))
io.write(string.format("✅ T2: GateDetector — %d/%d testes passaram\n", pass, pass + fail))
io.write("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

if fail > 0 then os.exit(1) else os.exit(0) end
